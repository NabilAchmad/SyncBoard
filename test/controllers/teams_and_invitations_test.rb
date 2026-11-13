require "test_helper"

class TeamsAndInvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @alpha = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @alpha_project = @alpha.projects.create!(name: "Alpha Secret Board", key: "ALPH", owner: @lead)
    @alpha_meeting = @alpha_project.meetings.create!(host: @lead, title: "Alpha Confidential Sync")
  end

  test "team invite code is always a 6-character mix of uppercase letters and numbers" do
    25.times do
      code = Team.generate_unique_invite_code
      assert_equal 6, code.length
      assert_match(/\A[A-Z0-9]{6}\z/, code)
      assert_match(/[A-Z]/, code)
      assert_match(/[0-9]/, code)
    end
  end

  test "new user without invite code gets completely empty workspace and cannot access other teams" do
    post registration_path, params: {
      user: {
        full_name: "User Baru Kosong",
        email_address: "kosong@perusahaan.com",
        department: "Engineering",
        job_title: "Backend Engineer",
        password: "strongpassword123",
        password_confirmation: "strongpassword123"
      }
    }
    assert_redirected_to root_path

    # Workspace is completely empty and shows Join / Create Team onboarding
    get root_path
    assert_response :success
    assert_select "h2", /Workspace Anda Masih Kosong/
    assert_no_match(/Alpha Secret Board/, response.body)

    # Cannot access projects, tasks, meetings, or project creation before joining a team
    get new_project_path
    assert_redirected_to root_path

    get project_path(@alpha_project)
    assert_redirected_to root_path

    get project_meeting_path(@alpha_project, @alpha_meeting)
    assert_redirected_to root_path

    assert_no_difference("Task.count") do
      post project_tasks_path(@alpha_project), params: { task: { title: "Cross-team Task" } }
    end
    assert_redirected_to root_path
  end

  test "registration rejects invalid invite code without creating user" do
    assert_no_difference("User.count") do
      post registration_path, params: {
        invite_code: "ZZZZ99",
        user: {
          full_name: "Salah Kode",
          email_address: "salahkode@perusahaan.com",
          department: "Engineering",
          job_title: "QA",
          password: "strongpassword123",
          password_confirmation: "strongpassword123"
        }
      }
    end
    assert_response :unprocessable_entity
    assert_match(/tidak ditemukan/, response.body)
  end

  test "user can create a new team as lead, join another team via 6-char code, switch teams, and regenerate code" do
    outsider = User.create!(
      full_name: "Dina Founder",
      email_address: "dina@perusahaan.com",
      department: "Product",
      job_title: "Product Manager",
      password: "strongpassword123",
      password_confirmation: "strongpassword123"
    )
    sign_in_as(outsider)

    # Create a new team from empty state -> creator automatically becomes Lead
    assert_difference("Team.count", 1) do
      post teams_path, params: {
        team: {
          name: "Tim Beta Produk",
          description: "Tim terpisah untuk produk baru"
        }
      }
    end
    beta = Team.find_by!(name: "Tim Beta Produk")
    assert_redirected_to root_path
    assert_equal 6, beta.invite_code.length
    assert outsider.lead_of?(beta)
    assert_not outsider.member_of?(@alpha)

    get root_path
    assert_response :success
    assert_includes response.body, beta.invite_code
    assert_no_match(/Alpha Secret Board/, response.body)
    assert_select "body[data-user-role='lead']"

    # Creating project with same key "ALPH" inside Team Beta succeeds (keys are scoped per team)
    assert_difference("Project.count", 1) do
      post projects_path, params: {
        project: {
          name: "Beta Workspace",
          key: "ALPH",
          description: "Key sama tetapi beda tim"
        }
      }
    end
    beta_project = beta.projects.find_by!(key: "ALPH")
    assert_not_equal @alpha_project.id, beta_project.id

    # Lead of Beta can regenerate invite code -> old code stops working
    old_code = beta.invite_code
    post regenerate_code_team_path(beta)
    assert_redirected_to team_members_path
    assert_not_equal old_code, beta.reload.invite_code

    # Join Team Alpha using Alpha's 6-character code -> becomes member (not lead) in Alpha
    post join_teams_path, params: { invite_code: "  #{@alpha.invite_code.downcase} " }
    assert_redirected_to root_path
    assert outsider.member_of?(@alpha)
    assert_not outsider.lead_of?(@alpha)

    get root_path
    assert_response :success
    assert_match(/Alpha Secret Board/, response.body)
    assert_select "body[data-user-role='member']"

    # Switch back to Beta -> becomes lead again in Beta
    post switch_team_path(beta)
    assert_redirected_to root_path
    get root_path
    assert_response :success
    assert_match(/Beta Workspace/, response.body)
    assert_select "body[data-user-role='lead']"

    # Cannot join with old regenerated code of Beta
    delete session_path
    sign_in_as(@member)
    post join_teams_path, params: { invite_code: old_code }
    assert_redirected_to root_path
    assert_not @member.reload.member_of?(beta)

    # Can join Beta using new code, and then leave Beta cleanly
    post join_teams_path, params: { invite_code: beta.invite_code }
    assert_redirected_to root_path
    assert @member.reload.member_of?(beta)

    delete leave_team_path(beta)
    assert_redirected_to root_path
    assert_not @member.reload.member_of?(beta)

    # Cross-team assignee cannot be assigned onto Alpha task
    invalid_task = @alpha_project.tasks.build(title: "Invalid Cross-Team", creator: @lead, assignee: outsider)
    assert invalid_task.valid? # outsider is currently a member of Alpha; remove outsider from Alpha first:
    outsider.membership_for(@alpha).destroy!
    assert_not invalid_task.valid?
    assert_not_empty invalid_task.errors[:assignee_id]
  end
end
