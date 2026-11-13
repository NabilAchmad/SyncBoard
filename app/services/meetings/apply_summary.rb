module Meetings
  class ApplySummary
    Result = Struct.new(:applied_count, :created_tasks, :updated_tasks, keyword_init: true)

    def initialize(meeting:, actor:)
      @meeting = meeting
      @actor = actor
      @project = meeting.project
    end

    def call
      raise ArgumentError, "Hanya Team Lead tim ini yang dapat menyetujui (ACC) rangkuman rapat." unless @actor.lead_of?(@project.team)

      created_tasks = []
      updated_tasks = []
      applied_count = 0

      ActiveRecord::Base.transaction do
        pending_items = @meeting.meeting_action_items.includes(:target_task, :assignee).where(selected: true, applied: false)

        pending_items.each do |item|
          case item.action_type
          when "create_task"
            task = apply_create_task!(item)
            created_tasks << task
            applied_count += 1
          when "move_task", "complete_task", "update_task"
            task = apply_existing_task_change!(item)
            updated_tasks << task if task
            applied_count += 1
          end
        end

        @meeting.update!(
          status: "approved",
          approved_by: @actor,
          approved_at: Time.current,
          ended_at: @meeting.ended_at || Time.current,
          rejection_reason: nil
        )

        @project.activity_logs.create!(
          user: @actor,
          meeting: @meeting,
          summary: "#{@actor.full_name} menyetujui (ACC) rangkuman '#{@meeting.title}' — #{applied_count} perubahan diterapkan ke Kanban"
        )

        @meeting.meeting_messages.create!(
          user: @actor,
          kind: "system",
          body: "Rangkuman rapat telah di-ACC oleh #{@actor.full_name}. #{applied_count} item perubahan otomatis diperbarui ke Kanban Board."
        )
      end

      @project.broadcast_kanban_refresh!
      @meeting.broadcast_summary_refresh!

      Result.new(applied_count: applied_count, created_tasks: created_tasks, updated_tasks: updated_tasks)
    end

    private
      def apply_create_task!(item)
        task = @project.tasks.create!(
          creator: @actor,
          assignee: item.assignee,
          source_meeting: @meeting,
          title: item.title,
          description: item.description.presence || "Dibuat otomatis dari ACC rapat #{@meeting.title}",
          column_status: item.target_column,
          priority: item.priority,
          due_date: item.due_date
        )
        item.update!(applied: true, target_task: task)
        task
      end

      def apply_existing_task_change!(item)
        task = item.target_task
        if task.nil? || task.project_id != @project.id
          return apply_create_task!(item)
        end

        target_col = item.action_type == "complete_task" ? "done" : item.target_column

        task.update!(
          priority: item.priority.presence || task.priority,
          assignee_id: item.assignee_id || task.assignee_id,
          source_meeting: @meeting,
          due_date: item.due_date || task.due_date,
          description: append_meeting_note(task.description, item.description)
        )

        if item.action_type != "update_task" || task.column_status != target_col
          Tasks::Move.new(
            task: task,
            target_column: target_col,
            actor: @actor,
            broadcast: false
          ).call
        end

        item.update!(applied: true)
        task.reload
      end

      def append_meeting_note(existing, note)
        return existing if note.blank?
        return note if existing.blank?
        return existing if existing.include?(note)

        "#{existing}\n\n[Rapat #{@meeting.room_code}] #{note}"
      end
  end
end
