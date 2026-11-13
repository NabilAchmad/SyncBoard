class TeamMembership < ApplicationRecord
  ROLES = User::ROLES

  belongs_to :team
  belongs_to :user

  scope :leads, -> { where(role: "lead") }
  scope :members, -> { where(role: "member") }

  before_validation :assign_joined_at, on: :create

  validates :role, presence: true, inclusion: { in: ROLES.keys }
  validates :user_id, uniqueness: { scope: :team_id, message: "sudah tergabung di tim ini" }
  validates :joined_at, presence: true

  def lead?
    role == "lead"
  end

  def role_label
    ROLES.fetch(role, "Anggota Tim")
  end

  private
    def assign_joined_at
      self.joined_at ||= Time.current
    end
end
