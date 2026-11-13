class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_team, :current_team_membership, :current_team_lead?, :available_teams

  private
    def available_teams
      return [] unless authenticated?

      @available_teams ||= current_user.teams.ordered.to_a
    end

    def current_team
      return @current_team if defined?(@current_team)
      return @current_team = nil unless authenticated?

      preferred = Current.session&.current_team
      resolved = if preferred && current_user.member_of?(preferred)
        preferred
      else
        available_teams.first
      end

      if Current.session && Current.session.current_team_id != resolved&.id
        Current.session.update!(current_team: resolved)
      end

      @current_team = resolved
    end

    def current_team_membership
      return nil unless authenticated? && current_team

      @current_team_membership ||= current_user.membership_for(current_team)
    end

    def current_team_lead?
      current_team_membership&.lead? || false
    end

    def set_current_team(team)
      @current_team = team
      @current_team_membership = nil
      @available_teams = nil
      Current.session&.update!(current_team: team)
    end

    def require_team!
      return if current_team.present?

      redirect_to root_path, alert: "Anda belum tergabung di tim mana pun. Masukkan kode undangan 6 karakter atau buat tim baru terlebih dahulu."
    end

    def load_authorized_project(param_key = :project_id)
      @project = current_user.team_projects.includes(team: :team_memberships).find_by(id: params[param_key])
      if @project.nil?
        redirect_to root_path, alert: "Proyek tidak ditemukan atau Anda tidak memiliki akses ke tim proyek tersebut."
        return false
      end

      set_current_team(@project.team) if @project.team_id != current_team&.id
      true
    end
end
