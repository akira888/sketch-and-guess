class RoomsController < ApplicationController
  def index; end

  def new
    # 新しいルームを作るので、古いセッションをクリア
    session[:user_id] = nil
    session[:room_id] = nil

    @cache_room = Cache::Room.new(initial_params)
  end

  def create
    @cache_room = Cache::Room.new(room_params)

    if @cache_room.save
      session[:room_id] = @cache_room.id
      flash[:notice] = "ゲームルームを作成しました"
      redirect_to room_path @cache_room
    else
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
      # お題選択フェーズの場合、お題選択画面にリダイレクト
      redirect_to prompt_selection_room_path(@cache_room.id)
      # else はユーザー参加待ち状態となる
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

  def prompt_selection
    @cache_room = Cache::Room.find(params[:id])
    @game = Cache::Game.find_by_room(@cache_room.id)
    @current_user = Cache::User.find(session[:user_id])

    unless @current_user
      flash[:alert] = "ユーザー情報が見つかりません"
      redirect_to root_path and return
    end

    unless @game&.prompt_selection?
      flash[:alert] = "お題選択フェーズではありません"
      redirect_to room_path(@cache_room.id) and return
    end

    # 現在のユーザーに割り当てられたcard_numの6つのお題を取得
    if @current_user.assigned_card_num
      @prompts = Prompt.by_card(@current_user.assigned_card_num).order(:order)
    else
      flash[:alert] = "お題が割り当てられていません"
      redirect_to room_path(@cache_room.id) and return
    end

    # ルーム作成者を判定（最初のメンバー）
    first_member = @cache_room.member_order_array.first
    @is_room_creator = first_member && first_member["user_id"] == @current_user.id
  end

  def submit_free_prompt
    @cache_room = Cache::Room.find(params[:id])
    @game = Cache::Game.find_by_room(@cache_room.id)
    @current_user = Cache::User.find(session[:user_id])

    unless @game
      render json: { error: "ゲームが見つかりません" }, status: :bad_request and return
    end

    unless @game.dice_result.present?
      render json: { error: "まだダイスが振られていません" }, status: :bad_request and return
    end

    prompt_text = params[:prompt_text]&.strip
    if prompt_text.blank?
      render json: { error: "お題を入力してください" }, status: :bad_request and return
    end

    begin
      # 現在のユーザーのスケッチブックを取得
      sketch_book_id = @current_user.sketch_book_id
      unless sketch_book_id
        render json: { error: "スケッチブックが見つかりません" }, status: :not_found and return
      end

      sketch_book = SketchBook.find(sketch_book_id)

      # スケッチブックのprompt_textを更新
      sketch_book.update!(prompt_text: prompt_text)

      # 1ページ目（お題ページ）のcontentも更新
      first_page = sketch_book.pages.find_by(page_number: 1)
      if first_page
        first_page.update!(content: prompt_text)
      end

      Rails.logger.info "Updated FREE prompt for user #{@current_user.name}: #{prompt_text}"

      render json: {
        success: true,
        message: "お題が設定されました",
        prompt_text: prompt_text
      }
    rescue => e
      Rails.logger.error "Failed to submit free prompt: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  def roll_dice
    @cache_room = Cache::Room.find(params[:id])
    @game = Cache::Game.find_by_room(@cache_room.id)
    @current_user = Cache::User.find(session[:user_id])

    unless @game&.prompt_selection?
      render json: { error: "お題選択フェーズではありません" }, status: :bad_request and return
    end

    # ダイスボタンの二重クリック防止
    if @game.dice_result.present?
      render json: { error: "既にダイスが振られています" }, status: :bad_request and return
    end

    begin
      # ダイスを振る（1-6）
      dice_result = rand(1..6)
      Rails.logger.info "Dice rolled: #{dice_result} for room #{@cache_room.id}"

      # ゲームを開始（全員分のスケッチブック作成）
      game_manager = GameManager.new(@cache_room)
      game_manager.finalize_game_start!(dice_result)

      # 全員にダイス結果とゲーム開始をブロードキャスト
      broadcast_dice_result(@cache_room, dice_result)

      render json: {
        success: true,
        dice_result: dice_result,
        message: "ダイスを振りました"
      }
    rescue => e
      Rails.logger.error "Failed to roll dice: #{e.message}"
      render json: { error: e.message }, status: :internal_server_error
    end
  end

  private
  def room_params
    params.require("cache_room").permit(:room_id, :member_limit, :total_round)
  end

  def initial_params
    { member_limit: 4, total_round: 1 }
  end

  def broadcast_dice_result(room, dice_result)
    # ダイス結果をブロードキャスト
    Turbo::StreamsChannel.broadcast_append_to(
      "room_#{room.id}_dice",
      target: "body",
      html: <<~HTML
        <script>
          window.diceResult = #{dice_result};
          const event = new CustomEvent('diceRolled', { detail: { result: #{dice_result} } });
          document.dispatchEvent(event);
        </script>
      HTML
    )
  end
end
