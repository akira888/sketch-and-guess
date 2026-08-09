class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def set_current_user
    return @current_user if @current_user.present?

    user_id = session[:user_id]
    @current_user = Cache::User.find(user_id)

    unless @current_user
      flash[:alert] = "ユーザー情報が見つかりません"
      redirect_to root_path
    end
  end
end
