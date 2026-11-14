# frozen_string_literal: true

require "test_helper"

class FathomSummaryTest < ActiveSupport::TestCase
  setup do
    @team = teams(:alpha)
    @lead = users(:two)
    @member = users(:one)
    @project = @team.projects.create!(name: "Sync Core", key: "CORE", owner: @lead)
    @task = @project.tasks.create!(
      title: "Setup Gateway Webhook",
      column_status: "in_progress",
      priority: "high",
      creator: @lead,
      assignee: @member
    )
    @meeting = @project.meetings.create!(
      host: @lead,
      title: "Incident Review & Planning"
    )
  end

  test "filters small talk, collapses incremental STT, extracts decisions, blockers, natural commitments and due dates" do
    @meeting.update!(transcript_text: <<~TEXT)
      Raka: Halo guys tes suara masuk aman sip wkwk
      Nabil: oke jadi sebenernya antrian webhook
      Nabil: antrian webhook di staging menumpuk saat beban CPU tinggi.
      Oke guys, performa endpoint webhook melambat 40% saat jam sibuk.
      [KEPUTUSAN] Kita sepakat pakai worker background Redis untuk antrian webhook.
      [BLOCKER] Rate limit payment gateway masih mentok di 10 req/s pada jam sibuk.
      Raka: Nabil tolong rapihin timeout Redis staging sebelum besok.
      [AKSI] Dokumentasi failover Redis untuk Raka deadline lusa prioritas high di kolom in progress.
      Task #{@task.code} kita pindahkan ke in review hari ini.
    TEXT

    @meeting.meeting_messages.create!(
      user: @member,
      kind: "chat",
      body: "Tolong Nabil cek metrik error produksi minggu depan"
    )

    Meetings::SummaryGenerator.new(meeting: @meeting, actor: @lead).call
    @meeting.reload

    parsed = ApplicationController.helpers.parse_fathom_summary(@meeting.summary_text)
    assert_nil parsed[:legacy_text]
    assert parsed[:tldr].present?
    assert_no_match(/wkwk|tes suara/i, parsed[:tldr])

    assert_equal 1, parsed[:decisions].size
    assert_match(/worker background Redis/i, parsed[:decisions].first)

    assert_equal 1, parsed[:blockers].size
    assert_match(/Rate limit payment gateway/i, parsed[:blockers].first)

    # Incremental partial phrase ("antrian webhook") must be collapsed into the complete line
    joined_points = parsed[:key_points].join("\n")
    assert_equal 1, parsed[:key_points].count { |point| point.downcase.include?("antrian webhook") }
    assert_match(/beban CPU tinggi/i, joined_points)
    assert_match(/performa endpoint webhook melambat 40%/i, joined_points)
    assert_no_match(/^Oke guys/i, joined_points)

    items = @meeting.meeting_action_items.order(:id).to_a

    timeout_item = items.find { |item| item.title.downcase.include?("rapihin timeout redis staging") }
    assert_not_nil timeout_item
    assert_equal "create_task", timeout_item.action_type
    assert_equal @member.id, timeout_item.assignee_id
    assert_equal Date.current + 1.day, timeout_item.due_date

    failover_item = items.find { |item| item.title.downcase.include?("dokumentasi failover redis") }
    assert_not_nil failover_item
    assert_equal @lead.id, failover_item.assignee_id
    assert_equal "high", failover_item.priority
    assert_equal "in_progress", failover_item.target_column
    assert_equal Date.current + 2.days, failover_item.due_date

    move_item = items.find { |item| item.target_task_id == @task.id }
    assert_not_nil move_item
    assert_equal "move_task", move_item.action_type
    assert_equal "review", move_item.target_column
    assert_equal Date.current, move_item.due_date

    chat_item = items.find { |item| item.title.downcase.include?("cek metrik error produksi") }
    assert_not_nil chat_item
    assert_equal @member.id, chat_item.assignee_id
    assert_equal Date.current + 7.days, chat_item.due_date
  end

  test "treats fix bug commitments as action items instead of false decisions" do
    @meeting.update!(transcript_text: <<~TEXT)
      Checkout gagal karena token CSRF kadaluarsa.
      Tolong Nabil fix bug token CSRF besok.
    TEXT

    Meetings::SummaryGenerator.new(meeting: @meeting, actor: @lead).call
    @meeting.reload

    parsed = ApplicationController.helpers.parse_fathom_summary(@meeting.summary_text)
    assert_empty parsed[:decisions]
    assert_equal 1, parsed[:blockers].size
    assert_match(/token CSRF/i, parsed[:blockers].first)

    item = @meeting.meeting_action_items.find_by("LOWER(title) LIKE ?", "%fix bug token csrf%")
    assert_not_nil item
    assert_equal @member.id, item.assignee_id
    assert_equal Date.current + 1.day, item.due_date
  end
end
