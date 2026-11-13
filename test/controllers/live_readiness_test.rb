require "test_helper"

class LiveReadinessTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:alpha)
    @member = users(:one)
    @lead = users(:two)
  end

  test "login and meeting views do not contain demo controls" do
    get new_session_path
    assert_response :success
    assert_no_match(/Akun Demo/i, response.body)
    assert_no_match(/syncboard\.test/i, response.body)

    sign_in_as(@lead)
    project = @team.projects.create!(name: "Live Workspace", key: "LIVE", owner: @lead)
    meeting = project.meetings.create!(host: @lead, title: "Kickoff Live")

    get project_meeting_path(project, meeting)
    assert_response :success
    assert_no_match(/Isi Contoh Transcript/i, response.body)
  end

  test "registration without invite code starts empty and joining with invite code enters team as member" do
    post registration_path, params: {
      user: {
        full_name: "Pengguna Mandiri",
        email_address: "mandiri@perusahaan.com",
        department: "Engineering",
        job_title: "CTO",
        password: "strongpassword123",
        password_confirmation: "strongpassword123"
      }
    }
    first_user = User.find_by!(email_address: "mandiri@perusahaan.com")
    assert_redirected_to root_path
    assert_empty first_user.teams

    get root_path
    assert_response :success
    assert_select "h2", /Workspace Anda Masih Kosong/

    delete session_path

    post registration_path, params: {
      invite_code: @team.invite_code.downcase,
      user: {
        full_name: "Engineer Kedua",
        email_address: "engineer@perusahaan.com",
        department: "Engineering",
        job_title: "Software Engineer",
        password: "strongpassword123",
        password_confirmation: "strongpassword123"
      }
    }
    second_user = User.find_by!(email_address: "engineer@perusahaan.com")
    assert_redirected_to root_path
    assert second_user.member_of?(@team)
    assert_not second_user.lead_of?(@team)
  end

  test "team members management is restricted to team leads and updates or removes memberships safely" do
    member_membership = @member.membership_for(@team)
    lead_membership = @lead.membership_for(@team)

    sign_in_as(@member)
    get team_members_path
    assert_redirected_to root_path

    patch team_member_path(lead_membership), params: { team_membership: { role: "member" } }
    assert_redirected_to root_path
    assert @lead.lead_of?(@team)

    delete session_path
    sign_in_as(@lead)

    get team_members_path
    assert_response :success
    assert_includes response.body, @team.invite_code

    patch team_member_path(member_membership), params: { team_membership: { role: "lead" } }
    assert_redirected_to team_members_path
    assert @member.reload.lead_of?(@team)

    # Lead cannot demote or remove themselves via team_members
    patch team_member_path(lead_membership), params: { team_membership: { role: "member" } }
    assert_redirected_to team_members_path
    assert @lead.reload.lead_of?(@team)

    delete team_member_path(lead_membership)
    assert_redirected_to team_members_path
    assert @lead.reload.member_of?(@team)

    # Removing a member clears their active team session reference
    @member.sessions.create!(current_team: @team)
    delete team_member_path(member_membership)
    assert_redirected_to team_members_path
    assert_not @member.reload.member_of?(@team)
    assert_equal 0, @member.sessions.where(current_team_id: @team.id).count
  end

  test "ending call with transcript keeps auto_join_call disabled after summary generation" do
    sign_in_as(@lead)
    project = @team.projects.create!(name: "WebRTC Call Flow", key: "WCF", owner: @lead)
    meeting = project.meetings.create!(host: @lead, title: "Call Termination Test", transcript_text: "Buat task baru uji koneksi TURN priority high.")

    # Generating summary mid-call keeps ended_at nil (call still active)
    post generate_summary_project_meeting_path(project, meeting), as: :turbo_stream
    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_nil meeting.reload.ended_at

    # Host ends call for everyone -> sets ended_at and disables auto-rejoin on page reload
    post end_call_project_meeting_path(project, meeting)
    assert_redirected_to project_meeting_path(project, meeting)
    assert_not_nil meeting.reload.ended_at

    get project_meeting_path(project, meeting)
    assert_response :success
    assert_select "[data-meeting-room-auto-join-call-value='false']"
    assert_select "[data-meeting-room-ice-servers-value]"
  end
end
