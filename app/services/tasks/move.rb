module Tasks
  class Move
    Result = Struct.new(:task, :moved, :column_changed, keyword_init: true)

    def initialize(task:, target_column:, actor:, target_position: nil, broadcast: true)
      @task = task
      @target_column = target_column.to_s
      @actor = actor
      @target_position = target_position&.to_i
      @broadcast = broadcast
    end

    def call
      raise ArgumentError, "Kolom target tidak valid" unless Task::COLUMNS.key?(@target_column)

      source_column = @task.column_status
      column_changed = source_column != @target_column
      old_label = Task::COLUMNS[source_column]
      new_label = Task::COLUMNS[@target_column]

      Task.transaction do
        target_ids = @task.project.tasks
                          .where(column_status: @target_column)
                          .where.not(id: @task.id)
                          .ordered_for_board
                          .pluck(:id)

        insert_index = if @target_position&.positive?
          [ @target_position - 1, target_ids.length ].min
        else
          target_ids.length
        end

        target_ids.insert(insert_index, @task.id)

        @task.update!(column_status: @target_column, position: insert_index + 1)

        target_ids.each_with_index do |id, idx|
          Task.where(id: id).update_all(position: idx + 1)
        end

        if column_changed
          normalize_column_positions!(source_column)
          @task.project.activity_logs.create!(
            user: @actor,
            summary: "#{@actor.full_name} memindahkan #{@task.code} (#{@task.title}) dari #{old_label} ke #{new_label}"
          )
        end
      end

      @task.project.broadcast_kanban_refresh! if @broadcast
      Result.new(task: @task.reload, moved: true, column_changed: column_changed)
    end

    private
      def normalize_column_positions!(column)
        ids = @task.project.tasks.where(column_status: column).ordered_for_board.pluck(:id)
        ids.each_with_index do |id, idx|
          Task.where(id: id).update_all(position: idx + 1)
        end
      end
  end
end
