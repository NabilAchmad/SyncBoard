class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  layout "auth"

  def new
    redirect_to root_path if authenticated?
    @user = User.new(department: "Engineering", job_title: "Fullstack Engineer")
  end

  def create
    @user = User.new(registration_params)
    normalized_code = params[:invite_code].to_s.strip.upcase.gsub(/[^A-Z0-9]/, "")
    invited_team = nil

    if normalized_code.present?
      invited_team = Team.find_by(invite_code: normalized_code)
      if invited_team.nil?
        @user.valid?
        @user.errors.add(:base, "Kode undangan tim '#{normalized_code}' tidak ditemukan. Periksa 6 digit kode dari Team Lead atau kosongkan untuk daftar tanpa tim.")
        render :new, status: :unprocessable_entity
        return
      end
    end

    saved = false
    User.transaction do
      @user.role = "member"
      saved = @user.save
      if saved && invited_team
        invited_team.team_memberships.create!(
          user: @user,
          role: "member",
          joined_at: Time.current
        )
      end
    end

    if saved
      session = start_new_session_for(@user)
      session.update!(current_team: invited_team) if invited_team

      notice = if invited_team
        "Akun SyncBoard berhasil dibuat dan bergabung ke tim #{invited_team.name}!"
      else
        "Akun SyncBoard berhasil dibuat! Masukkan kode undangan 6 karakter atau buat tim baru untuk memulai."
      end
      redirect_to root_path, notice: notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.require(:user).permit(:full_name, :email_address, :department, :job_title, :phone, :password, :password_confirmation)
    end
end
