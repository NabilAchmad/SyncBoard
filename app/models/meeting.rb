class Meeting < ApplicationRecord
  STATUSES = {
    "live" => "Sedang Berlangsung",
    "ended" => "Panggilan Selesai",
    "summary_ready" => "Menunggu ACC Lead",
    "approved" => "Disetujui & Diterapkan",
    "rejected" => "Ditolak"
  }.freeze

  belongs_to :project
  belongs_to :host, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :meeting_messages, -> { order(:created_at, :id) }, dependent: :destroy
  has_many :meeting_action_items, -> { order(:id) }, dependent: :destroy
  has_many :generated_tasks, class_name: "Task", foreign_key: :source_meeting_id, dependent: :nullify
  has_many :activity_logs, dependent: :nullify

  scope :recent_first, -> { order(started_at: :desc, id: :desc) }
  scope :open_rooms, -> { where(ended_at: nil, status: %w[live summary_ready]) }

  before_validation :assign_defaults, on: :create

  validates :title, presence: true, length: { maximum: 120 }
  validates :room_code, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validates :started_at, presence: true

  def status_label
    STATUSES.fetch(status, status.humanize)
  end

  def live?
    status == "live"
  end

  def call_open?
    ended_at.nil? && %w[live summary_ready].include?(status)
  end

  def ended?
    status == "ended"
  end

  def summary_ready?
    status == "summary_ready"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def pending_approval?
    pending_items = if meeting_action_items.loaded?
      meeting_action_items.any? { |item| item.selected? && !item.applied? }
    else
      meeting_action_items.where(selected: true, applied: false).exists?
    end

    pending_items || summary_ready?
  end

  def broadcast_summary_refresh!
    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :room ],
      target: ActionView::RecordIdentifier.dom_id(self, :summary_panel),
      partial: "meetings/summary_panel",
      locals: {
        meeting: self,
        project: project,
        team_members: project.team.users.active.ordered_by_name,
        project_tasks: project.tasks.ordered_for_board
      }
    )
  end

  private
    def assign_defaults
      self.started_at ||= Time.current
      self.room_code ||= generate_unique_room_code
    end

    def generate_unique_room_code
      loop do
        prefix = project&.key.presence || "SYNC"
        candidate = "#{prefix}-#{SecureRandom.alphanumeric(4).upcase}"
        break candidate unless Meeting.exists?(room_code: candidate)
      end
    end
end
