class UsersController < ApplicationController
  def new
    @cache_room = Cache::Room.find params[:room_id]
    render "not_found", status: 404 unless @cache_room

    session[:room_id] = @cache_room.id
    @cache_user = Cache::User.new(room_id: @cache_room.id)
  end

  def create
    @cache_room = Cache::Room.find session[:room_id]

    if @cache_room.full?
      render "busy", status: 403
      return
    end

    @cache_user = Cache::User.new(user_params)
    if @cache_user.save
      # 参加者リストに追加
      @cache_room.add_member(@cache_user.id, @cache_user.name)
      session[:user_id] = @cache_user.id

      # 定員に達したか確認
      if @cache_room.full?
        # ゲーム自動開始
        begin
          game_manager = GameManager.new(@cache_room)
          game = game_manager.start_game!

          flash[:notice] = "ゲームを開始しました！"
          redirect_to sketch_book_path(@cache_user.current_sketch_book_id || @cache_user.sketch_book_id)
        rescue => e
          flash[:alert] = "ゲーム開始に失敗しました: #{e.message}"
          redirect_to room_path(@cache_room.id)
        end
      else
        # まだ定員に達していない場合は待機画面へ
        flash[:notice] = "ルームに参加しました（#{@cache_room.entering_count}/#{@cache_room.member_limit}人）"
        redirect_to room_path(@cache_room.id)
      end
    else
      render :new
    end
  end

  def show
    @cache_user = Cache::User.find(params[:id])
    unless @cache_user
      render "not_found", status: 404
    end
  end

  private

  def user_params
    params.require("cache_user").permit(:name, :room_id)
  end
end
