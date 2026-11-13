class AddDueDateToMeetingActionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :meeting_action_items, :due_date, :date
  end
end
