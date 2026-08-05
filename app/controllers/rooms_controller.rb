class RoomsController < ApplicationController
  MEMBER_LIMIT_RANGE = 4..8
  MEMBER_LIMIT_RANGE_DEV = 2..8

  def index; end

  def new
    # 新しいルームを作るので、古いセッションをクリア
    session[:user_id] = nil
    session[:room_id] = nil

    @cache_room = Cache::Room.new(initial_params)
    @member_limit_range = Rails.env.development? ? MEMBER_LIMIT_RANGE_DEV : MEMBER_LIMIT_RANGE
  end

  def create
    @cache_room = Cache::Room.new(room_params)

    if @cache_room.save
      session[:room_id] = @cache_room.id
      game = Cache::Game.new(room_id: @cache_room.id)
      if game.save
        redirect_to room_path(@cache_room), notice: "ゲームルームを作成しました"
      else
        flash[:alert] = "ゲームルームの作成に失敗しました"
        render :new
      end
    else
      flash[:alert] = "ゲームルームの作成に失敗しました"
      render :new
    end
  end

  def show
    @cache_room = Cache::Room.find(params[:id])
    @game = Cache::Game.find_by_room(@cache_room.id)

    # ゲームの状態に応じて表示を変える
    if @game&.finished?
      redirect_to results_room_path(@cache_room.id)
    elsif @game&.in_progress?
      # ゲームが進行中の場合、ユーザーのスケッチブックにリダイレクト
      user = Cache::User.find(session[:user_id])
      if user&.current_sketch_book_id
        redirect_to sketch_book_path(user.current_sketch_book_id)
      end
    elsif @game&.prompt_selection?
      # else はゲーム開始前の待機画面となる
    end
  end

  def results
    @cache_room = Cache::Room.find(params[:id])
    @game = Cache::Game.find_by_room(@cache_room.id)

    # 完成したスケッチブックを取得
    @sketch_books = SketchBook.where(room_id: @cache_room.id, completed: true)
                              .includes(pages: { image_attachment: :blob })
                              .order(:id)

    unless @game&.finished?
      flash[:alert] = "ゲームがまだ終了していません"
      redirect_to room_path(@cache_room.id)
      return
    end

    # 結果を表示したら、ユーザーのゲーム関連データをクリア
    # （次のゲームのために）
    if session[:user_id]
      user = Cache::User.find(session[:user_id])
      if user
        user.current_sketch_book_id = nil
        user.sketch_book_id = nil
        user.assigned_card_num = nil
        user.save
        Rails.logger.info "Cleared game data for user #{user.name} after viewing results"
      end
    end
  end

  def game_redirect
    room_id = params[:id]
    game = Cache::Game.find_by_room(room_id)
    user_id = session[:user_id]
    user = Cache::User.find(user_id)

    response_data = {}

    # ゲームステータスを追加
    if game
      response_data[:game_status] = game.status
      # ダイス結果も追加（お題選択後の表示用）
      response_data[:dice_result] = game.dice_result if game.dice_result

      # ゲーム進行中の場合、全員の準備ができているかチェック
      if game.in_progress?
        # FREEお題がまだ入力されていないスケッチブックがあるかチェック
        pending_free_prompts = SketchBook.where(room_id: room_id)
                                         .where("prompt_text = ? OR prompt_text LIKE ? OR prompt_text LIKE ?",
                                                "FREE", "FREE:%", "FREE_CHOICE:%")
                                         .exists?
        response_data[:all_ready] = !pending_free_prompts
      end
    end

    # お題選択フェーズの場合
    if game&.prompt_selection?
      response_data[:prompt_selection] = true
      render json: response_data
      return
    end

    # ゲーム進行中の場合、スケッチブックURLを返す
    if user&.current_sketch_book_id
      response_data[:sketch_book_id] = user.current_sketch_book_id
      response_data[:sketch_book_url] = sketch_book_path(user.current_sketch_book_id)
      render json: response_data
    else
      render json: response_data.merge(error: "No sketch book found"), status: :not_found
    end
  end

  def game_next_turn
    room_id = params[:id]
    game = Cache::Game.find_by_room(room_id)
    user_id = session[:user_id]
    user = Cache::User.find(user_id)

    # ゲームが終了している場合は結果画面へ
    if game&.finished? || game&.round_finished?
      render json: {
        game_finished: true,
        results_url: results_room_path(room_id)
      }
    elsif user&.current_sketch_book_id
      render json: {
        game_finished: false,
        sketch_book_id: user.current_sketch_book_id,
        sketch_book_url: sketch_book_path(user.current_sketch_book_id)
      }
    else
      render json: { error: "No sketch book found" }, status: :not_found
    end
  end

  private
  def room_params
    params.require("cache_room").permit(:room_id, :member_limit, :total_round)
  end

  def initial_params
    { member_limit: 4, total_round: 1 }
  end
end
