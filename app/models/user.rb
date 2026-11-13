class User < ApplicationRecord
  ROLES = {
    "member" => "Anggota Tim",
    "lead" => "Team Lead"
  }.freeze

  DEPARTMENTS = [
    "Engineering",
    "Product",
    "Design",
    "Marketing",
    "Finance",
    "HRD",
    "Operations"
  ].freeze

  ALLOWED_AVATAR_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :owned_teams, class_name: "Team", foreign_key: :owner_id, dependent: :restrict_with_exception
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :team_projects, through: :teams, source: :projects
  has_many :owned_projects, class_name: "Project", foreign_key: :owner_id, dependent: :restrict_with_exception
  has_many :created_tasks, class_name: "Task", foreign_key: :creator_id, dependent: :restrict_with_exception
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, dependent: :nullify
  has_many :hosted_meetings, class_name: "Meeting", foreign_key: :host_id, dependent: :restrict_with_exception
  has_many :approved_meetings, class_name: "Meeting", foreign_key: :approved_by_id, dependent: :nullify
  has_many :meeting_messages, dependent: :destroy
  has_many :activity_logs, dependent: :nullify
  has_one_attached :avatar

  scope :active, -> { where(active: true) }
  scope :ordered_by_name, -> { order(:full_name, :id) }

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :employee_code, with: ->(c) { c.to_s.strip.upcase }

  before_validation :assign_employee_code, on: :create

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true, length: { maximum: 80 }
  validates :employee_code, presence: true, uniqueness: true, length: { maximum: 20 }
  validates :department, presence: true, inclusion: { in: DEPARTMENTS }
  validates :job_title, presence: true, length: { maximum: 60 }
  validates :phone, length: { maximum: 25 }, allow_blank: true
  validates :role, presence: true, inclusion: { in: ROLES.keys }
  validate :acceptable_avatar

  def lead?
    role == "lead"
  end

  def role_label
    ROLES.fetch(role, "Anggota Tim")
  end

  def initials
    full_name.to_s.split(/\s+/).first(2).map { |part| part[0] }.join.upcase.presence || "TM"
  end

  def membership_for(team)
    return nil if team.nil?

    if team_memberships.loaded?
      team_memberships.find { |membership| membership.team_id == team.id }
    else
      team_memberships.find_by(team_id: team.id)
    end
  end

  def member_of?(team)
    membership_for(team).present?
  end

  def lead_of?(team)
    membership_for(team)&.lead? || false
  end

  private
    def assign_employee_code
      return if employee_code.present?

      last_num = User.pluck(:employee_code).filter_map do |code|
        match = code.to_s.match(/\A(?:EMP|TM)-(\d+)\z/)
        match[1].to_i if match
      end.max || 0

      self.employee_code = format("TM-%03d", last_num + 1)
    end

    def acceptable_avatar
      return unless avatar.attached?

      unless ALLOWED_AVATAR_TYPES.include?(avatar.blob.content_type)
        errors.add(:avatar, "harus berupa PNG, JPG, WebP, atau GIF")
      end

      if avatar.blob.byte_size > 2.megabytes
        errors.add(:avatar, "ukuran maksimal 2 MB")
      end
    end
end
