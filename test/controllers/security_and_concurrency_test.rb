# frozen_string_literal: true

require "test_helper"

class SecurityAndConcurrencyTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "Guard Board", key: "GRD", owner: @lead)
    @meeting = @project.meetings.create!(host: @lead, title: "Security Sync", status: "summary_ready")
    @meeting.meeting_action_items.create!(
      action_type: "create_task",
      title: "Pasang audit log webhook",
      target_column: "todo",
      priority: "high",
      assignee: @member,
      selected: true
    )

    @outsider = User.create!(
      full_name: "Outsider User",
      email_address: "outsider_sec@perusahaan.com",
      password: "strongpassword123",
      department: "Engineering",
      job_title: "QA Engineer",
      active: true
    )
  end

  test "double approve is idempotent and does not duplicate tasks or logs" do
    sign_in_as(@lead)

    assert_difference -> { @project.tasks.count }, 1 do
      assert_difference -> { @project.activity_logs.count }, 1 do
        post approve_project_meeting_path(@project, @meeting)
        assert_redirected_to project_meeting_path(@project, @meeting)
      end
    end

    assert_no_difference -> { @project.tasks.count } do
      assert_no_difference -> { @project.activity_logs.count } do
        post approve_project_meeting_path(@project, @meeting)
        assert_redirected_to project_meeting_path(@project, @meeting)
      end
    end

    assert_match(/sudah di-ACC sebelumnya/i, flash[:notice])
  end

  test "prevents cross-team IDOR and member privilege escalation on approve" do
    sign_in_as(@outsider)
    get project_path(@project)
    assert_redirected_to root_path

    post approve_project_meeting_path(@project, @meeting)
    assert_redirected_to root_path
    assert_not @meeting.reload.approved?

    sign_in_as(@member)
    post approve_project_meeting_path(@project, @meeting)
    assert_redirected_to project_meeting_path(@project, @meeting)
    assert_not @meeting.reload.approved?
  end
end
