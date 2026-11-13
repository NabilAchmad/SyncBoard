class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  layout "auth"
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Terlalu banyak percobaan login. Coba lagi beberapa menit lagi." }

  def new
    redirect_to root_path if authenticated?
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      unless user.active?
        redirect_to new_session_path, alert: "Akun Anda sedang dinonaktifkan. Hubungi Team Lead."
        return
      end

      start_new_session_for(user)
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Email atau password tidak sesuai."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
