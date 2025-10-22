class UsersController < ApplicationController
  def new
    @cache_room = Cache::Room.find params[:room_id]
    render "not_found", status: 404 unless @cache_room

    session[:room_id] = @cache_room.id
    @cache_user = Cache::User.new(room_id: @cache_room.id)
  end

  def create
    @cache_room = Cache::Room.find session[:room_id]
    render "busy", status: 403 if @cache_room.full?

    @cache_user = Cache::User.new(user_params)
    if @cache_user.save
      entering_count = @cache_room.entering_count + 1
      @cache_room.update(entering_count:)
      session[:user_id] = @cache_user.id
      flash[:notice] = "ユーザー登録が完了しました"
      redirect_to new_sketch_book_path
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
