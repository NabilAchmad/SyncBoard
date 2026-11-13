require "test_helper"

class MeetingChannelTest < ActionCable::Channel::TestCase
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @project = @team.projects.create!(name: "Realtime Audio Video", key: "RAV", owner: @lead)
    @meeting = @project.meetings.create!(host: @lead, title: "Sync WebRTC Room")
    stub_connection current_user: @lead
  end

  test "subscribes to meeting stream and relays WebRTC signaling" do
    subscribe(meeting_id: @meeting.id, client_id: "tab-alpha")
    assert subscription.confirmed?
    assert_has_stream_for @meeting

    assert_broadcast_on(@meeting, {
      type: "peer_joined",
      sender_id: "tab-alpha",
      target_id: nil,
      audio_enabled: true,
      video_enabled: false,
      screen_sharing: false,
      user: {
        id: @lead.id,
        full_name: @lead.full_name,
        initials: @lead.initials,
        job_title: @lead.job_title,
        role_label: @lead.role_label,
        lead: true
      }
    }) do
      perform :join, client_id: "tab-alpha", audio_enabled: true, video_enabled: false, screen_sharing: false
    end

    assert_broadcast_on(@meeting, {
      type: "signal",
      signal_type: "offer",
      sender_id: "tab-alpha",
      target_id: "tab-beta",
      payload: { type: "offer", sdp: "v=0" },
      audio_enabled: false,
      video_enabled: false,
      screen_sharing: false,
      user: {
        id: @lead.id,
        full_name: @lead.full_name,
        initials: @lead.initials,
        job_title: @lead.job_title,
        role_label: @lead.role_label,
        lead: true
      }
    }) do
      perform :signal, client_id: "tab-alpha", target_id: "tab-beta", signal_type: "offer", payload: { type: "offer", sdp: "v=0" }
    end

    assert_broadcast_on(@meeting, {
      type: "peer_left",
      sender_id: "tab-alpha",
      user_id: @lead.id
    }) do
      perform :leave, client_id: "tab-alpha"
    end

    assert_broadcast_on(@meeting, {
      type: "peer_left",
      sender_id: "tab-alpha",
      user_id: @lead.id
    }) do
      unsubscribe
    end
  end

  test "rejects unknown meeting, inactive user, or non-team member" do
    subscribe(meeting_id: -1, client_id: "tab-ghost")
    assert subscription.rejected?

    outsider = User.create!(
      email_address: "outsider-cable@example.com",
      full_name: "Orang Luar",
      department: "Engineering",
      job_title: "Engineer",
      password: "password123",
      password_confirmation: "password123"
    )
    stub_connection current_user: outsider
    subscribe(meeting_id: @meeting.id, client_id: "tab-outsider")
    assert subscription.rejected?

    stub_connection current_user: @lead
    @lead.update!(active: false)
    subscribe(meeting_id: @meeting.id, client_id: "tab-disabled")
    assert subscription.rejected?
  end
end
