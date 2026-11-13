class Task < ApplicationRecord
  COLUMNS = {
    "todo" => "To Do",
    "in_progress" => "In Progress",
    "review" => "In Review",
    "done" => "Done"
  }.freeze

  PRIORITIES = {
    "low" => "Low",
    "medium" => "Medium",
    "high" => "High",
    "urgent" => "Urgent"
  }.freeze

  APPROACHING_DUE_DAYS = 2

  belongs_to :project
  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true
  belongs_to :source_meeting, class_name: "Meeting", optional: true
  has_many :meeting_action_items, foreign_key: :target_task_id, dependent: :nullify

  scope :ordered_for_board, -> { order(:position, :id) }

  before_validation :assign_code_and_position, on: :create

  validates :title, presence: true, length: { maximum: 140 }
  validates :code, presence: true, uniqueness: { scope: :project_id }
  validates :column_status, presence: true, inclusion: { in: COLUMNS.keys }
  validates :priority, presence: true, inclusion: { in: PRIORITIES.keys }
  validate :assignee_belongs_to_project_team, if: :validate_assignee_membership?

  def column_label
    COLUMNS.fetch(column_status, column_status.humanize)
  end

  def priority_label
    PRIORITIES.fetch(priority, priority.humanize)
  end

  def due_status(reference_date = Date.current)
    return :none if due_date.blank?
    return :completed if column_status == "done"
    return :overdue if due_date < reference_date
    return :approaching if due_date <= reference_date + APPROACHING_DUE_DAYS.days

    :on_track
  end

  def days_until_due(reference_date = Date.current)
    return nil if due_date.blank?

    (due_date - reference_date).to_i
  end

  private
    def validate_assignee_membership?
      assignee_id.present? && project&.team_id.present? && (new_record? || will_save_change_to_assignee_id? || will_save_change_to_project_id?)
    end

    def assignee_belongs_to_project_team
      return if assignee&.member_of?(project.team)

      errors.add(:assignee_id, "harus merupakan anggota tim proyek ini")
    end

    def assign_code_and_position
      return unless project

      self.code ||= project.next_task_code
      if position.nil? || position.zero?
        max_pos = project.tasks.where(column_status: column_status).maximum(:position) || 0
        self.position = max_pos + 1
      end
    end
end
