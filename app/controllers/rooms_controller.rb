class RoomsController < ApplicationController
  def index; end

  def new
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
    # ここでゲーム進行する？
  end

  private
  def room_params
    params.require('cache_room').permit(:room_id, :member_limit, :total_round)
  end

  def initial_params
    {member_limit: 4, total_round: 1}
  end
end
