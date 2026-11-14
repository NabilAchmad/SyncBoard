class Project < ApplicationRecord
  STATUSES = {
    "active" => "Aktif",
    "completed" => "Selesai",
    "archived" => "Diarsipkan"
  }.freeze

  belongs_to :team
  belongs_to :owner, class_name: "User"
  has_many :tasks, dependent: :destroy
  has_many :meetings, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  normalizes :key, with: ->(value) { value.to_s.strip.upcase.gsub(/[^A-Z0-9]/, "").first(6) }

  before_validation :assign_default_key, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :key, presence: true, uniqueness: { scope: :team_id }, format: { with: /\A[A-Z0-9]{2,6}\z/, message: "harus 2-6 karakter huruf/angka" }
  validates :status, presence: true, inclusion: { in: STATUSES.keys }

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end

  def all_tasks_done?
    tasks.exists? && !tasks.where.not(column_status: "done").exists?
  end

  def next_task_code
    prefix = key.presence || "PRJ"
    last_num = tasks.pluck(:code).filter_map do |code|
      match = code.to_s.match(/\A#{Regexp.escape(prefix)}-(\d+)\z/)
      match[1].to_i if match
    end.max || 0

    "#{prefix}-#{last_num + 1}"
  end

  def task_counts_by_column
    counts = Task::COLUMNS.keys.index_with { 0 }
    if tasks.loaded?
      tasks.each do |task|
        counts[task.column_status] += 1 if counts.key?(task.column_status)
      end
    else
      tasks.group(:column_status).count.each do |column, total|
        counts[column] = total if counts.key?(column)
      end
    end
    counts
  end

  def broadcast_kanban_refresh!
    tasks_by_column = tasks.includes(:assignee, :source_meeting).ordered_for_board.group_by(&:column_status)

    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :kanban ],
      target: ActionView::RecordIdentifier.dom_id(self, :kanban_board),
      partial: "projects/kanban_board",
      locals: { project: self, tasks_by_column: tasks_by_column }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :kanban ],
      target: ActionView::RecordIdentifier.dom_id(self, :activity_feed),
      partial: "projects/activity_feed",
      locals: { project: self, activity_logs: activity_logs.includes(:user, :meeting).recent_first.limit(12) }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      [ self, :kanban ],
      target: ActionView::RecordIdentifier.dom_id(self, :completion_banner),
      partial: "projects/completion_banner",
      locals: { project: self }
    )
  end

  private
    def assign_default_key
      return if key.present?

      candidate = name.to_s.upcase.gsub(/[^A-Z0-9]/, "").first(4)
      candidate = "PRJ" if candidate.length < 2
      self.key = candidate
    end
end
