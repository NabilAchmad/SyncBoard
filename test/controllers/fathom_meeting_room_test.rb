# frozen_string_literal: true

require "test_helper"

class FathomMeetingRoomTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "Fathom UI", key: "FTHM", owner: @lead)
    @meeting = @project.meetings.create!(host: @lead, title: "Sprint Alignment")
    sign_in_as(@lead)
  end

  test "meeting room renders quick highlight controls and summary generator actions" do
    get project_meeting_path(@project, @meeting)
    assert_response :success
    assert_no_match(/material-symbols-outlined/, response.body)

    assert_select "button[data-action='click->meeting-room#selectCaptionTag'][data-tag='decision']", text: "Keputusan"
    assert_select "button[data-action='click->meeting-room#selectCaptionTag'][data-tag='action']", text: "Aksi"
    assert_select "button[data-action='click->meeting-room#selectCaptionTag'][data-tag='blocker']", text: "Blocker"
    assert_select "button", text: /Rangkum Inti Sekarang/
    assert_select "input[data-meeting-room-target='endCallTranscriptField']"
  end

  test "end_call syncs unsaved transcript_text param and renders Fathom summary cards" do
    unsaved_transcript = <<~TEXT
      Raka: Halo tes mic
      [KEPUTUSAN] Kita sepakat rilis API v2 pada hari Senin.
      [BLOCKER] Sertifikat SSL staging belum diperbarui.
      [AKSI] Perbarui sertifikat SSL staging untuk Nabil besok prioritas urgent.
    TEXT

    post end_call_project_meeting_path(@project, @meeting), params: { transcript_text: unsaved_transcript }
    assert_redirected_to project_meeting_path(@project, @meeting)

    @meeting.reload
    assert_not_nil @meeting.ended_at
    assert_equal "summary_ready", @meeting.status
    assert_equal unsaved_transcript, @meeting.transcript_text

    follow_redirect!
    assert_response :success
    assert_match(/TL;DR Inti Rapat/, response.body)
    assert_match(/Keputusan Disepakati/, response.body)
    assert_match(/Blocker &amp; Risiko/, response.body)
    assert_match(/Rangkum Ulang/, response.body)
    assert_match(/Perbarui sertifikat SSL staging/i, response.body)
  end

  test "end_call auto-summarizes when only regular chat discussion messages exist" do
    @meeting.meeting_messages.create!(
      user: @member,
      kind: "chat",
      body: "[KEPUTUSAN] Sepakat tunda deploy sampai query N+1 selesai diperbaiki."
    )

    post end_call_project_meeting_path(@project, @meeting)
    assert_redirected_to project_meeting_path(@project, @meeting)

    @meeting.reload
    assert_equal "summary_ready", @meeting.status
    assert_includes @meeting.summary_text, "[TL;DR]"
    assert_includes @meeting.summary_text, "[KEPUTUSAN]"
  end
end
