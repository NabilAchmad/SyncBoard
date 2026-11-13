class MeetingActionItem < ApplicationRecord
  ACTION_TYPES = {
    "create_task" => "Buat Task Baru",
    "move_task" => "Pindahkan Kolom",
    "update_task" => "Update Task",
    "complete_task" => "Selesaikan Task"
  }.freeze
  EXISTING_ACTION_TYPES = (ACTION_TYPES.keys - [ "create_task" ]).freeze

  belongs_to :meeting
  belongs_to :target_task, class_name: "Task", optional: true
  belongs_to :assignee, class_name: "User", optional: true

  before_validation :normalize_target_column

  validates :action_type, presence: true, inclusion: { in: ACTION_TYPES.keys }
  validates :title, presence: true, length: { maximum: 140 }
  validates :target_column, presence: true, inclusion: { in: Task::COLUMNS.keys }
  validates :priority, presence: true, inclusion: { in: Task::PRIORITIES.keys }
  validate :target_task_belongs_to_meeting_project

  def action_type_label
    ACTION_TYPES.fetch(action_type, action_type.humanize)
  end

  def creates_new_task?
    action_type == "create_task"
  end

  def updates_existing_task?
    !creates_new_task?
  end

  private
    def normalize_target_column
      self.target_column = "done" if action_type == "complete_task"
      self.target_task_id = nil if creates_new_task?
    end

    def target_task_belongs_to_meeting_project
      return if target_task_id.blank? || meeting&.project_id.blank?
      return if target_task&.project_id == meeting.project_id

      errors.add(:target_task_id, "harus berasal dari proyek yang sama")
    end
end
