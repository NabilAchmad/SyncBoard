class TeamMembersController < ApplicationController
  before_action :require_team!
  before_action :require_lead!
  before_action :set_membership, only: %i[update destroy]

  def index
    @memberships = current_team.team_memberships
      .eager_load(user: { avatar_attachment: :blob })
      .merge(User.ordered_by_name)
      .to_a
  end

  def update
    if @membership.user_id == current_user.id
      redirect_to team_members_path, alert: "Anda tidak dapat mengubah role diri sendiri di tim ini."
      return
    end

    if @membership.update(role: requested_role)
      redirect_to team_members_path, notice: "Role #{@membership.user.full_name} di tim #{current_team.name} diperbarui menjadi #{@membership.role_label}."
    else
      redirect_to team_members_path, alert: @membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @membership.user_id == current_user.id
      redirect_to team_members_path, alert: "Gunakan menu keluar tim jika ingin meninggalkan tim ini."
      return
    end

    removed_name = @membership.user.full_name
    removed_user_id = @membership.user_id
    @membership.destroy!
    Session.where(user_id: removed_user_id, current_team_id: current_team.id).update_all(current_team_id: nil)

    redirect_to team_members_path, notice: "#{removed_name} telah dikeluarkan dari tim #{current_team.name}."
  end

  private
    def set_membership
      @membership = current_team.team_memberships.find_by(id: params[:id])
      return if @membership

      redirect_to team_members_path, alert: "Anggota tidak ditemukan pada tim ini."
    end

    def requested_role
      params.require(:team_membership).permit(:role)[:role].to_s
    end

    def require_lead!
      return if current_team_lead?

      redirect_to root_path, alert: "Hanya Team Lead tim ini yang dapat mengelola anggota dan kode undangan."
    end
end
