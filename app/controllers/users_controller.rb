class UsersController < ApplicationController
  def new
    @cache_room = Cache::Room.find params[:room_id]
    unless @cache_room
      render "not_found", status: 404
    end
  end
end
