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

  def next_page
    set_current_user
    game = Cache::Game.find_by_room(@current_user.room_id)
    resolve_id = game.sketch_book_id_held_by(@current_user.id)
    if resolve_id
      redirect_to new_sketch_book_page_path(resolve_id)
    else
      flash[:alert] = "スケッチブックの割り出しに失敗"
      redirect_to sketch_book_first_page_path(@current_user.sketch_book_id)
    end
  end

  # legacy
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

  private
  def room_params
    params.require("cache_room").permit(:room_id, :member_limit, :total_round)
  end

  def initial_params
    { member_limit: 4, total_round: 1 }
  end
end
