require "test_helper"

class QueryPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "Perf Board", key: "PERF", owner: @lead)
    @meeting = @project.meetings.create!(host: @lead, title: "Perf Sync")

    extra_users = 5.times.map do |idx|
      user = User.create!(
        full_name: "Perf Member #{idx}",
        email_address: "perf_member_#{idx}@perusahaan.com",
        password: "strongpassword123",
        department: "Engineering",
        job_title: "Engineer",
        active: true
      )
      @team.team_memberships.create!(user: user, role: "member", joined_at: Time.current)
      user
    end

    extra_users.each_with_index do |assignee, idx|
      @project.tasks.create!(
        title: "Task #{idx}",
        column_status: "todo",
        priority: "medium",
        creator: @lead,
        assignee: assignee,
        source_meeting: @meeting
      )
      @meeting.meeting_messages.create!(user: assignee, kind: "chat", body: "Halo #{idx}")
      @project.activity_logs.create!(user: assignee, meeting: @meeting, summary: "Log #{idx}")
    end

    sign_in_as(@lead)
  end

  test "edit project, workspace index, kanban board, and meeting room stay free of N+1 queries" do
    edit_queries = capture_queries { get edit_project_path(@project) }
    assert_response :success
    assert_operator edit_queries.size, :<=, 4, "Expected /projects/:id/edit <= 4 queries, got #{edit_queries.size}:\n#{edit_queries.join("\n")}"

    index_queries = capture_queries { get root_path }
    assert_response :success
    assert_operator index_queries.size, :<=, 7, "Expected GET / <= 7 queries, got #{index_queries.size}:\n#{index_queries.join("\n")}"
    assert_includes response.body, "0% (0/5)"
    assert_includes response.body, "Gabung Room · #{@meeting.room_code}"

    teams_queries = capture_queries { get teams_path }
    assert_response :success
    assert_operator teams_queries.size, :<=, 4, "Expected GET /teams <= 4 queries, got #{teams_queries.size}:\n#{teams_queries.join("\n")}"

    team_members_queries = capture_queries { get team_members_path }
    assert_response :success
    assert_operator team_members_queries.size, :<=, 4, "Expected GET /team_members <= 4 queries, got #{team_members_queries.size}:\n#{team_members_queries.join("\n")}"

    show_queries = capture_queries { get project_path(@project) }
    assert_response :success
    assert_operator show_queries.size, :<=, 8, "Expected /projects/:id <= 8 queries, got #{show_queries.size}:\n#{show_queries.join("\n")}"

    meeting_queries = capture_queries { get project_meeting_path(@project, @meeting) }
    assert_response :success
    assert_operator meeting_queries.size, :<=, 10, "Expected /projects/:id/meetings/:id <= 10 queries, got #{meeting_queries.size}:\n#{meeting_queries.join("\n")}"
  end

  private
    def capture_queries(&block)
      sqls = []
      callback = ->(_name, _start, _finish, _id, payload) do
        return if payload[:name] == "SCHEMA" || payload[:cached]
        return if payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|PRAGMA)/i)

        sqls << payload[:sql].gsub(/\s+/, " ").strip
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
      sqls
    end
end
