class ProjectsController < ApplicationController
  before_action :require_team!, only: %i[new create]
  before_action :set_project, only: %i[show edit update complete]

  def index
    if current_team.present?
      @projects = current_team.projects.includes(:owner, :tasks, :meetings).ordered
      @recent_logs = ActivityLog.joins(:project)
        .where(projects: { team_id: current_team.id })
        .includes(:project, :user, :meeting)
        .recent_first
        .limit(10)
      @team_memberships = current_team.team_memberships
        .includes(user: { avatar_attachment: :blob })
        .joins(:user)
        .merge(User.active.ordered_by_name)
    else
      @projects = Project.none
      @recent_logs = ActivityLog.none
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
    @tasks_by_column = @project.tasks.includes(:assignee, :source_meeting).ordered_for_board.group_by(&:column_status)
    @team_members = @project.team.users.active.ordered_by_name
    @meetings = @project.meetings.includes(:host, :approved_by, :meeting_action_items).recent_first
    @activity_logs = @project.activity_logs.includes(:user, :meeting).recent_first.limit(12)
    @new_task = @project.tasks.build(column_status: "todo", priority: "medium")
    @new_meeting = @project.meetings.build
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
