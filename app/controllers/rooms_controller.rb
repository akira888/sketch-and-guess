class RoomsController < ApplicationController
  def index; end

  def new
    @cache_room = Cache::Room.new(initial_params)
  end

  def create
    @cache_room = Cache::Room.new(room_params)
    @cache_room.entering_count = 0

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
    end
  end

  def game_redirect
    user_id = session[:user_id]
    user = Cache::User.find(user_id)

    if user&.current_sketch_book_id
      render json: {
        sketch_book_id: user.current_sketch_book_id,
        sketch_book_url: sketch_book_path(user.current_sketch_book_id)
      }
    else
      render json: { error: "No sketch book found" }, status: :not_found
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
