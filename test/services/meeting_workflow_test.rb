require "test_helper"

class MeetingWorkflowTest < ActiveSupport::TestCase
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "SyncBoard Demo", key: "SBD", owner: @lead)
    @task_one = @project.tasks.create!(title: "Setup WebRTC signaling", column_status: "in_progress", priority: "high", creator: @lead)
    @task_two = @project.tasks.create!(title: "Testing UI board", column_status: "todo", priority: "medium", creator: @lead)
    @meeting = @project.meetings.create!(
      host: @lead,
      title: "Weekly Tech Sync",
      transcript_text: <<~TEXT
        Raka: Task #{@task_one.code} sudah beres QA, tandai done sekarang.
        Nabil: Task #{@task_two.code} kita pindahkan ke in review hari ini.
        Nabil: Tolong buat task baru integrasi notifikasi push untuk Nabil priority urgent.
      TEXT
    )
    @meeting.meeting_messages.create!(
      user: @lead,
      kind: "decision",
      body: "Buat task dokumentasi API WebRTC di kolom todo."
    )
  end

  test "SummaryGenerator parses existing task completions, moves, and new tasks" do
    Meetings::SummaryGenerator.new(meeting: @meeting, actor: @member).call
    @meeting.reload

    assert_equal "summary_ready", @meeting.status
    assert_includes @meeting.summary_text, "Weekly Tech Sync"

    items = @meeting.meeting_action_items.to_a
    assert_equal 4, items.size

    complete_item = items.find { |i| i.action_type == "complete_task" }
    assert_not_nil complete_item
    assert_equal @task_one.id, complete_item.target_task_id
    assert_equal "done", complete_item.target_column

    move_item = items.find { |i| i.action_type == "move_task" }
    assert_not_nil move_item
    assert_equal @task_two.id, move_item.target_task_id
    assert_equal "review", move_item.target_column

    new_item = items.find { |i| i.title.include?("Integrasi notifikasi push") }
    assert_not_nil new_item
    assert_equal "create_task", new_item.action_type
    assert_equal "urgent", new_item.priority
    assert_equal @member.id, new_item.assignee_id
  end

  test "ApplySummary rejects non-lead actors and applies changes atomically for lead" do
    Meetings::SummaryGenerator.new(meeting: @meeting, actor: @lead).call

    assert_raises(ArgumentError) do
      Meetings::ApplySummary.new(meeting: @meeting, actor: @member).call
    end
    assert_equal "summary_ready", @meeting.reload.status

    # Deselect satu item supaya kita verifikasi hanya item selected yang diterapkan
    optional_item = @meeting.meeting_action_items.find { |i| i.title.downcase.include?("dokumentasi api") }
    assert_not_nil optional_item
    optional_item.update!(selected: false)

    result = Meetings::ApplySummary.new(meeting: @meeting, actor: @lead).call

    assert_equal 3, result.applied_count
    assert_equal "approved", @meeting.reload.status
    assert_equal @lead, @meeting.approved_by
    assert_equal "done", @task_one.reload.column_status
    assert_equal "review", @task_two.reload.column_status
    assert_equal 3, @project.tasks.count
    assert_not optional_item.reload.applied?
    assert @project.tasks.exists?(source_meeting: @meeting, column_status: "todo")
  end

  test "ApplySummary sets due_date on new tasks and updates due_date on existing tasks" do
    new_due = Date.current + 3.days
    update_due = Date.current + 1.day

    create_item = @meeting.meeting_action_items.create!(
      action_type: "create_task",
      title: "Tambah endpoint notifikasi target",
      target_column: "todo",
      priority: "high",
      assignee: @member,
      due_date: new_due
    )
    update_item = @meeting.meeting_action_items.create!(
      action_type: "update_task",
      target_task: @task_two,
      title: "Update #{@task_two.code} dan pasang target",
      target_column: "in_progress",
      priority: "urgent",
      due_date: update_due
    )
    @meeting.update!(status: "summary_ready")

    Meetings::ApplySummary.new(meeting: @meeting, actor: @lead).call

    created_task = @project.tasks.find_by!(title: "Tambah endpoint notifikasi target")
    assert_equal @meeting.id, created_task.source_meeting_id
    assert_equal new_due, created_task.due_date
    assert_not_nil created_task.created_at
    assert_equal update_due, @task_two.reload.due_date
    assert_equal "urgent", @task_two.priority
    assert create_item.reload.applied?
    assert update_item.reload.applied?
  end
end
