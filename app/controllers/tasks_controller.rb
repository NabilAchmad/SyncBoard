class TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: %i[edit update destroy move]

  def create
    @task = @project.tasks.build(task_params)
    @task.creator = current_user

    if @task.save
      @project.activity_logs.create!(
        user: current_user,
        summary: "#{current_user.full_name} menambahkan task #{@task.code}: #{@task.title}"
      )
      @project.broadcast_kanban_refresh!

      respond_to do |format|
        format.html { redirect_to @project, notice: "Task #{@task.code} berhasil ditambahkan ke Kanban." }
        format.turbo_stream { head :ok }
      end
    else
      redirect_to @project, alert: @task.errors.full_messages.to_sentence
    end
  end

  def edit
    @team_members = @project.team.users.active.ordered_by_name
  end

  def update
    old_column = @task.column_status

    if @task.update(task_params)
      if old_column != @task.column_status
        @project.activity_logs.create!(
          user: current_user,
          summary: "#{current_user.full_name} memindahkan #{@task.code} ke #{Task::COLUMNS[@task.column_status]}"
        )
      else
        @project.activity_logs.create!(
          user: current_user,
          summary: "#{current_user.full_name} memperbarui detail #{@task.code}"
        )
      end

      @project.broadcast_kanban_refresh!
      redirect_to @project, notice: "Task #{@task.code} diperbarui."
    else
      @team_members = @project.team.users.active.ordered_by_name
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    code = @task.code
    title = @task.title
    @task.destroy!

    @project.activity_logs.create!(
      user: current_user,
      summary: "#{current_user.full_name} menghapus task #{code} (#{title})"
    )
    @project.broadcast_kanban_refresh!

    redirect_to @project, status: :see_other, notice: "Task #{code} berhasil dihapus."
  end

  def move
    result = Tasks::Move.new(
      task: @task,
      target_column: params[:column_status],
      target_position: params[:position],
      actor: current_user
    ).call

    respond_to do |format|
      format.json do
        render json: {
          status: "ok",
          task: {
            id: result.task.id,
            code: result.task.code,
            column_status: result.task.column_status,
            position: result.task.position
          }
        }
      end
      format.turbo_stream { head :ok }
      format.html { redirect_to @project }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
      format.html { redirect_to @project, alert: e.message }
    end
  end

  private
    def set_project
      load_authorized_project(:project_id)
    end

    def set_task
      @task = @project.tasks.find(params[:id])
    end

    def task_params
      params.require(:task).permit(:title, :description, :column_status, :priority, :assignee_id, :due_date)
    end
end
