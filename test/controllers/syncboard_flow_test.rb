require "test_helper"

class SyncboardFlowTest < ActionDispatch::IntegrationTest
  setup do
    @member = users(:one)
    @lead = users(:two)
  end

  test "redirects unauthenticated visitors to sign in" do
    get root_path
    assert_redirected_to new_session_path

    get "/dashboard"
    assert_redirected_to root_path
  end

  test "full Kanban and Meeting Summary ACC flow enforces lead approval and updates board" do
    sign_in_as(@member)

    get root_path
    assert_response :success
    assert_select "h2", /Kelola Proyek/

    # Member membuat proyek baru
    assert_difference("Project.count", 1) do
      post projects_path, params: {
        project: {
          name: "Portal Kolaborasi",
          key: "PKL",
          description: "Project testing Kanban & Meeting"
        }
      }
    end
    project = Project.find_by!(key: "PKL")
    assert_redirected_to project_path(project)

    # Member membuat task awal di board
    assert_difference("Task.count", 1) do
      post project_tasks_path(project), params: {
        task: {
          title: "Inisialisasi Modul Chat",
          column_status: "todo",
          priority: "high",
          assignee_id: @member.id
        }
      }
    end
    task = project.tasks.first
    assert_equal "PKL-1", task.code

    # Drag & drop task ke kolom in_progress via JSON endpoint
    patch move_project_task_path(project, task), params: {
      column_status: "in_progress",
      position: 1
    }, as: :json
    assert_response :success
    assert_equal "in_progress", task.reload.column_status

    # Member membuka ruang meeting
    assert_difference("Meeting.count", 1) do
      post project_meetings_path(project), params: {
        meeting: {
          title: "Diskusi Fitur Notifikasi",
          agenda: "Review PKL-1 dan rencanakan task baru"
        }
      }
    end
    meeting = project.meetings.last
    assert_redirected_to project_meeting_path(project, meeting)
    get project_meeting_path(project, meeting)
    assert_response :success
    assert_select "[data-controller='meeting-room']"
    assert_select "[data-meeting-room-target='quickCaptionInput']"
    assert_select "[data-meeting-room-target='mirrorButton']"
    assert_select "[data-meeting-room-target='callButton']", text: /Akhiri Panggilan/
    assert_select "[data-meeting-room-target='endCallModal']"

    # Peserta lain (bukan Host pembuat room) hanya melihat "Keluar dari Panggilan" & tidak boleh end_call
    delete session_path
    sign_in_as(@lead)
    get project_meeting_path(project, meeting)
    assert_response :success
    assert_select "[data-meeting-room-target='callButton']", text: /Keluar dari Panggilan/
    assert_select "[data-meeting-room-target='endCallModal']", count: 0

    post end_call_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "live", meeting.reload.status

    # Kembali ke Host pembuat room (@member) untuk akhiri panggilan untuk semua
    delete session_path
    sign_in_as(@member)
    post end_call_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "ended", meeting.reload.status
    assert_not_nil meeting.ended_at

    # Member simpan transcript & generate summary
    patch save_transcript_project_meeting_path(project, meeting), params: {
      transcript_text: "Nabil: PKL-1 sudah selesai dan siap mark done.\nNabil: Buat task baru deployment worker production priority high."
    }, as: :json
    assert_response :success

    post generate_summary_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "summary_ready", meeting.reload.status

    get project_meeting_path(project, meeting)
    assert_response :success
    assert_select "h3", /Rangkuman & Usulan Perubahan Kanban/

    # Member tidak boleh ACC atau Reject rangkuman
    post approve_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "summary_ready", meeting.reload.status

    post reject_project_meeting_path(project, meeting), params: { rejection_reason: "Coba bypass" }
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "summary_ready", meeting.reload.status

    # Ganti sesi ke Team Lead untuk ACC rangkuman
    delete session_path
    sign_in_as(@lead)

    post approve_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)

    get project_meeting_path(project, meeting)
    assert_response :success
    assert_select "span", /Disetujui & Diterapkan/

    assert_equal "approved", meeting.reload.status
    assert_equal "done", task.reload.column_status
    assert_equal 2, project.tasks.count
    assert project.tasks.exists?(source_meeting: meeting)

    get project_path(project)
    assert_response :success
    assert_select "article", text: /PKL-1/
    assert_select "article", text: /Deployment worker production/i
    assert_select "article", text: /Dibuat \d{2} \w+ \d{4}/
    assert_select "article", text: /ACC Rapat #{meeting.room_code}/

    get edit_project_task_path(project, task)
    assert_response :success

    get edit_profile_path
    assert_response :success
  end

  test "kanban cards tint overdue and approaching due dates softly and meeting action modes work" do
    sign_in_as(@lead)
    team = teams(:alpha)
    project = team.projects.create!(name: "Board Target", key: "TRG", owner: @lead)
    overdue_task = project.tasks.create!(
      title: "Ticket Terlewati",
      column_status: "todo",
      due_date: Date.current - 2.days,
      creator: @lead
    )
    approaching_task = project.tasks.create!(
      title: "Ticket Mendekati",
      column_status: "in_progress",
      due_date: Date.current + 1.day,
      creator: @lead
    )
    done_overdue_task = project.tasks.create!(
      title: "Ticket Sudah Selesai",
      column_status: "done",
      due_date: Date.current - 5.days,
      creator: @lead
    )

    get project_path(project)
    assert_response :success
    assert_select "article#task_#{overdue_task.id}.bg-rose-50\\/75.border-rose-200", text: /Terlewati/
    assert_select "article#task_#{approaching_task.id}.bg-amber-50\\/75.border-amber-200", text: /Besok/
    assert_select "article#task_#{done_overdue_task.id}.bg-white.border-slate-200"

    meeting = project.meetings.create!(host: @lead, title: "Planning Target", status: "summary_ready")
    target_due = Date.current + 4.days

    # Mode existing tanpa target_task_id harus ditolak dengan pesan error
    post add_action_item_project_meeting_path(project, meeting), params: {
      item_mode: "existing",
      meeting_action_item: { action_type: "update_task", target_column: "review", priority: "high" }
    }
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal 0, meeting.meeting_action_items.count

    # Mode existing valid: update ticket yang sudah ada dengan due_date baru
    post add_action_item_project_meeting_path(project, meeting), params: {
      item_mode: "existing",
      meeting_action_item: {
        action_type: "update_task",
        target_task_id: overdue_task.id,
        title: "",
        target_column: "review",
        priority: "urgent",
        due_date: target_due.to_s
      }
    }
    assert_redirected_to project_meeting_path(project, meeting)
    existing_item = meeting.meeting_action_items.last
    assert existing_item.updates_existing_task?
    assert_equal overdue_task.id, existing_item.target_task_id
    assert_equal target_due, existing_item.due_date

    # Mode create valid + ubah via update_action_item
    post add_action_item_project_meeting_path(project, meeting), params: {
      item_mode: "create",
      meeting_action_item: {
        title: "Ticket Baru Dari Meet",
        target_column: "todo",
        priority: "medium",
        due_date: Date.current.to_s
      }
    }
    assert_redirected_to project_meeting_path(project, meeting)
    created_item = meeting.meeting_action_items.last
    assert created_item.creates_new_task?

    patch update_action_item_project_meeting_path(project, meeting, item_id: created_item.id), params: {
      item_mode: "create",
      meeting_action_item: {
        title: "Ticket Baru Dari Meet Direvisi",
        target_column: "in_progress",
        priority: "high",
        due_date: (Date.current + 1.day).to_s
      }
    }
    assert_redirected_to project_meeting_path(project, meeting)
    assert_equal "Ticket Baru Dari Meet Direvisi", created_item.reload.title

    post approve_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)

    assert_equal "review", overdue_task.reload.column_status
    assert_equal target_due, overdue_task.due_date
    new_task = project.tasks.find_by!(title: "Ticket Baru Dari Meet Direvisi")
    assert_equal meeting.id, new_task.source_meeting_id
    assert_equal Date.current + 1.day, new_task.due_date
  end
end
