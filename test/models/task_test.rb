require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "Sync Core", key: "SYNC", owner: @lead)
  end

  test "assigns sequential code and position within project" do
    t1 = @project.tasks.create!(title: "Task Pertama", creator: @lead)
    t2 = @project.tasks.create!(title: "Task Kedua", creator: @member)

    assert_equal "SYNC-1", t1.code
    assert_equal 1, t1.position
    assert_equal "SYNC-2", t2.code
    assert_equal 2, t2.position
  end

  test "Tasks::Move transitions column, reorders positions, and logs activity" do
    t1 = @project.tasks.create!(title: "Setup API", creator: @lead, column_status: "todo")
    t2 = @project.tasks.create!(title: "Setup UI", creator: @lead, column_status: "review")

    result = Tasks::Move.new(
      task: t1,
      target_column: "review",
      target_position: 1,
      actor: @member
    ).call

    assert result.moved
    assert result.column_changed
    assert_equal "review", t1.reload.column_status
    assert_equal 1, t1.position
    assert_equal 2, t2.reload.position
    assert_match(/memindahkan SYNC-1/, @project.activity_logs.last.summary)
  end

  test "Tasks::Move safely truncates activity log summary for long task titles" do
    long_title = "Implementasi end-to-end observability distributed tracing metric pipeline telemetry " * 2
    t = @project.tasks.create!(title: long_title.first(140), column_status: "todo", creator: @lead)

    assert_nothing_raised do
      Tasks::Move.new(task: t, target_column: "done", actor: @member).call
    end
    assert_equal "done", t.reload.column_status
    assert @project.activity_logs.last.summary.length <= 255
  end

  test "due_status classifies none, overdue, approaching, on_track, and completed tasks" do
    today = Date.new(2026, 11, 13)

    no_due = @project.tasks.create!(title: "Tanpa Target", creator: @lead)
    overdue = @project.tasks.create!(title: "Telat", creator: @lead, column_status: "todo", due_date: today - 1.day)
    due_today = @project.tasks.create!(title: "Hari Ini", creator: @lead, column_status: "in_progress", due_date: today)
    due_soon = @project.tasks.create!(title: "Besok", creator: @lead, column_status: "review", due_date: today + 2.days)
    on_track = @project.tasks.create!(title: "Masih Lama", creator: @lead, column_status: "todo", due_date: today + 5.days)
    done_late = @project.tasks.create!(title: "Sudah Selesai", creator: @lead, column_status: "done", due_date: today - 3.days)

    assert_equal :none, no_due.due_status(today)
    assert_equal :overdue, overdue.due_status(today)
    assert_equal(-1, overdue.days_until_due(today))

    assert_equal :approaching, due_today.due_status(today)
    assert_equal 0, due_today.days_until_due(today)

    assert_equal :approaching, due_soon.due_status(today)
    assert_equal 2, due_soon.days_until_due(today)

    assert_equal :on_track, on_track.due_status(today)
    assert_equal :completed, done_late.due_status(today)
  end
end
