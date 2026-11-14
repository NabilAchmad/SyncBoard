class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_team, :current_team_membership, :current_team_lead?, :available_teams, :sidebar_active_projects

  private
    def available_teams
      return [] unless authenticated?

      @available_teams ||= if current_user.team_memberships.loaded?
        current_user.team_memberships.filter_map(&:team).uniq(&:id).sort_by { |team| [ team.created_at, team.id ] }
      else
        current_user.teams.ordered.to_a
      end
    end

    def current_team
      return @current_team if defined?(@current_team)
      return @current_team = nil unless authenticated?

      preferred_id = Current.session&.current_team_id
      resolved = (preferred_id && available_teams.find { |team| team.id == preferred_id }) || available_teams.first

      if Current.session && Current.session.current_team_id != resolved&.id
        Current.session.update!(current_team: resolved)
      end

      @current_team = resolved
    end

    def sidebar_active_projects
      return [] unless authenticated? && current_team

      @sidebar_active_projects ||= if defined?(@projects) && @projects.is_a?(Array) && @projects.all? { |project| project.team_id == current_team.id }
        @projects.select(&:active?).first(10)
      else
        current_team.projects.active.ordered.limit(10).to_a
      end
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
      @sidebar_active_projects = nil
      Current.session&.update!(current_team: team)
    end

    def require_team!
      return if current_team.present?

      redirect_to root_path, alert: "Anda belum tergabung di tim mana pun. Masukkan kode undangan 6 karakter atau buat tim baru terlebih dahulu."
    end

    def load_authorized_project(param_key = :project_id)
      team_ids = available_teams.map(&:id)
      @project = team_ids.any? ? Project.where(team_id: team_ids).find_by(id: params[param_key]) : nil
      if @project.nil?
        redirect_to root_path, alert: "Proyek tidak ditemukan atau Anda tidak memiliki akses ke tim proyek tersebut."
        return false
      end

      matched_team = available_teams.find { |team| team.id == @project.team_id }
      @project.association(:team).target = matched_team if matched_team
      set_current_team(@project.team) if @project.team_id != current_team&.id
      true
    end

    def preload_records_with_known_map(records, foreign_key, association, known_by_id, fallback_preload: association)
      missing = []
      records.each do |record|
        id = record.public_send(foreign_key)
        next if id.nil?

        if (target = known_by_id[id])
          record.association(association).target = target
        else
          missing << record
        end
      end

      return if missing.empty?

      ActiveRecord::Associations::Preloader.new(records: missing, associations: fallback_preload).call
    end
end
