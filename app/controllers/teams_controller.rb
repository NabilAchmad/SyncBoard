class TeamsController < ApplicationController
  before_action :set_team, only: %i[update switch regenerate_code leave]

  def index
    @memberships = load_memberships_with_stats
    @new_team = Team.new
  end

  def create
    @team = Team.new(team_params)
    @team.owner = current_user

    Team.transaction do
      @team.save!
      @team.team_memberships.create!(
        user: current_user,
        role: "lead",
        joined_at: Time.current
      )
    end

    set_current_team(@team)
    redirect_to root_path, notice: "Tim '#{@team.name}' berhasil dibuat! Kode Undangan Anda: #{@team.invite_code}"
  rescue ActiveRecord::RecordInvalid
    @memberships = load_memberships_with_stats
    @new_team = @team
    flash.now[:alert] = @team.errors.full_messages.to_sentence
    render :index, status: :unprocessable_entity
  end

  def update
    unless current_user.lead_of?(@team)
      redirect_to root_path, alert: "Hanya Team Lead tim ini yang dapat mengubah detail tim."
      return
    end

    if @team.update(team_params)
      redirect_back fallback_location: team_members_path, notice: "Informasi tim diperbarui."
    else
      redirect_back fallback_location: team_members_path, alert: @team.errors.full_messages.to_sentence
    end
  end

  def join
    code = params[:invite_code].to_s.strip.upcase.gsub(/[^A-Z0-9]/, "")

    unless code.match?(Team::INVITE_CODE_FORMAT)
      redirect_back fallback_location: root_path, alert: "Kode undangan tim harus terdiri dari 6 karakter huruf & angka."
      return
    end

    team = Team.find_by(invite_code: code)
    if team.nil?
      redirect_back fallback_location: root_path, alert: "Kode undangan '#{code}' tidak ditemukan."
      return
    end

    if current_user.member_of?(team)
      set_current_team(team)
      redirect_to root_path, notice: "Anda sudah tergabung di tim '#{team.name}'."
      return
    end

    team.team_memberships.create!(
      user: current_user,
      role: "member",
      joined_at: Time.current
    )
    set_current_team(team)

    redirect_to root_path, notice: "Berhasil bergabung ke tim '#{team.name}'!"
  end

  def switch
    set_current_team(@team)
    redirect_to root_path, notice: "Beralih ke workspace tim '#{@team.name}'."
  end

  def regenerate_code
    unless current_user.lead_of?(@team)
      redirect_back fallback_location: team_members_path, alert: "Hanya Team Lead yang dapat membuat ulang kode undangan."
      return
    end

    @team.regenerate_invite_code!
    redirect_back fallback_location: team_members_path, notice: "Kode undangan baru dibuat: #{@team.invite_code}"
  end

  def leave
    membership = current_user.team_memberships.find_by!(team_id: @team.id)
    other_members_exist = @team.team_memberships.where.not(user_id: current_user.id).exists?
    other_lead_exists = @team.team_memberships.leads.where.not(user_id: current_user.id).exists?

    if membership.lead? && other_members_exist && !other_lead_exists
      redirect_back fallback_location: teams_path, alert: "Tunjuk Team Lead lain terlebih dahulu sebelum keluar dari tim '#{@team.name}'."
      return
    end

    membership.destroy!
    next_team = current_user.teams.ordered.where.not(id: @team.id).first
    set_current_team(next_team)

    redirect_to root_path, notice: "Anda telah keluar dari tim '#{@team.name}'."
  end

  private
    def set_team
      team_id = params[:id].to_i
      @team = available_teams.find { |team| team.id == team_id }
      return if @team

      redirect_to root_path, alert: "Tim tidak ditemukan atau Anda bukan anggota tim tersebut."
    end

    def load_memberships_with_stats
      memberships = if current_user.team_memberships.loaded?
        current_user.team_memberships.sort_by { |membership| [ membership.joined_at || Time.at(0), membership.id || 0 ] }
      else
        current_user.team_memberships.includes(:team).order(joined_at: :asc, id: :asc).to_a
      end

      teams = memberships.filter_map(&:team)
      ActiveRecord::Associations::Preloader.new(records: teams, associations: %i[team_memberships projects]).call if teams.any?
      memberships
    end

    def team_params
      params.require(:team).permit(:name, :description)
    end
end
