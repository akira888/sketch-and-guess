class SketchBooksController < ApplicationController
  def new
    @cache_user = Cache::User.find session[:user_id]
    @cache_room = Cache::Room.find @cache_user.room_id
    @prompts = serve_prompt_card
  end

  def serve_prompt_card
    []
  end
end
