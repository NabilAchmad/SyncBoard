class ProjectsController < ApplicationController
  before_action :require_team!, only: %i[new create]
  before_action :set_project, only: %i[show edit update complete]

  def index
    if current_team.present?
      @projects = current_team.projects
        .ordered
        .to_a
      @team_memberships = current_team.team_memberships
        .eager_load(user: { avatar_attachment: :blob })
        .merge(User.active.ordered_by_name)
        .to_a

      users_by_id = @team_memberships.each_with_object({}) { |membership, map| map[membership.user_id] = membership.user }
      preload_records_with_known_map(
        @projects,
        :owner_id,
        :owner,
        users_by_id,
        fallback_preload: { owner: { avatar_attachment: :blob } }
      )

      projects_by_id = @projects.index_by(&:id)
      if projects_by_id.any?
        project_ids = projects_by_id.keys
        default_counts = Task::COLUMNS.keys.index_with { 0 }
        @task_counts_by_project = project_ids.index_with { default_counts.dup }
        Task.where(project_id: project_ids).group(:project_id, :column_status).count.each do |(project_id, column_status), total|
          counts = @task_counts_by_project[project_id]
          counts[column_status] = total if counts&.key?(column_status)
        end

        open_first_order = Arel.sql(
          "CASE WHEN ended_at IS NULL AND status IN ('live', 'summary_ready') THEN 0 ELSE 1 END ASC, started_at DESC, id DESC"
        )
        @latest_meetings_by_project = {}
        Meeting.where(project_id: project_ids)
          .select(:id, :project_id, :room_code, :status, :ended_at, :started_at)
          .order(open_first_order)
          .each do |meeting|
            @latest_meetings_by_project[meeting.project_id] ||= meeting
          end

        @recent_logs = ActivityLog.where(project_id: project_ids)
          .select(:id, :project_id, :summary, :created_at)
          .recent_first
          .limit(10)
          .to_a
          .tap do |logs|
            preload_records_with_known_map(logs, :project_id, :project, projects_by_id)
          end
      else
        @task_counts_by_project = {}
        @latest_meetings_by_project = {}
        @recent_logs = []
      end
    else
      @projects = []
      @task_counts_by_project = {}
      @latest_meetings_by_project = {}
      @recent_logs = []
      @team_memberships = []
      @new_team = Team.new
    end
  end

  def new
    @project = current_team.projects.build
  end

  def create
    @project = current_team.projects.build(project_params)
    @project.owner = current_user

    if @project.save
      @project.activity_logs.create!(
        user: current_user,
        summary: "#{current_user.full_name} membuat proyek baru #{@project.name} (#{@project.key})"
      )
      redirect_to @project, notice: "Proyek #{@project.name} berhasil dibuat."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @team_members = @project.team.active_members_with_avatars
    users_by_id = @team_members.index_by(&:id)

    @meetings = @project.meetings
      .recent_first
      .select(:id, :project_id, :host_id, :title, :room_code, :status, :started_at, :ended_at, :approved_at, :created_at)
      .to_a
    @project.association(:meetings).target = @meetings
    meetings_by_id = @meetings.index_by(&:id)

    all_tasks = @project.tasks.ordered_for_board.to_a
    preload_records_with_known_map(
      all_tasks,
      :assignee_id,
      :assignee,
      users_by_id,
      fallback_preload: { assignee: { avatar_attachment: :blob } }
    )
    preload_records_with_known_map(all_tasks, :source_meeting_id, :source_meeting, meetings_by_id)
    @project.association(:tasks).target = all_tasks
    @tasks_by_column = all_tasks.group_by(&:column_status)

    @activity_logs = @project.activity_logs
      .select(:id, :project_id, :meeting_id, :summary, :created_at)
      .recent_first
      .limit(12)
      .to_a
    preload_records_with_known_map(@activity_logs, :meeting_id, :meeting, meetings_by_id)

    @new_task = Task.new(project: @project, column_status: "todo", priority: "medium")
    @new_meeting = Meeting.new(project: @project)
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Pengaturan proyek diperbarui."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def complete
    unless @project.team.lead?(current_user)
      redirect_to @project, alert: "Hanya Team Lead yang dapat menandai proyek selesai."
      return
    end

    unless @project.all_tasks_done?
      redirect_to @project, alert: "Seluruh tiket di Kanban harus masuk ke kolom Done terlebih dahulu."
      return
    end

    if @project.active?
      @project.update!(status: "completed")
      @project.activity_logs.create!(
        user: current_user,
        summary: "#{current_user.full_name} menandai proyek #{@project.name} (#{@project.key}) Selesai"
      )
      @project.broadcast_kanban_refresh!
    end

    redirect_to @project, notice: "Proyek #{@project.name} ditandai Selesai."
  end

  private
    def set_project
      load_authorized_project(:id)
    end

    def project_params
      params.require(:project).permit(:name, :key, :description, :status)
    end
end
