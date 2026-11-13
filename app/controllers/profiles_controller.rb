class ProfilesController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if params[:remove_avatar] == "1" && @user.avatar.attached?
      @user.avatar.purge
    end

    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: "Profil anggota berhasil diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:full_name, :phone, :department, :job_title, :avatar)
    end
end
