class ActivityLog < ApplicationRecord
  belongs_to :project
  belongs_to :user, optional: true
  belongs_to :meeting, optional: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  before_validation :truncate_summary

  validates :summary, presence: true, length: { maximum: 255 }

  private
    def truncate_summary
      self.summary = summary.to_s.strip.truncate(255) if summary.present?
    end
end
