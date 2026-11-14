class Team < ApplicationRecord
  LETTERS = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z].freeze
  DIGITS = %w[2 3 4 5 6 7 8 9].freeze
  INVITE_CODE_FORMAT = /\A[A-Z0-9]{6}\z/

  belongs_to :owner, class_name: "User"
  has_many :team_memberships, dependent: :destroy
  has_many :users, through: :team_memberships
  has_many :projects, dependent: :destroy
  has_many :active_sessions, class_name: "Session", foreign_key: :current_team_id, dependent: :nullify

  scope :ordered, -> { order(created_at: :asc, id: :asc) }

  normalizes :invite_code, with: ->(code) { code.to_s.strip.upcase.gsub(/[^A-Z0-9]/, "").first(6) }

  before_validation :assign_invite_code, on: :create

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 250 }, allow_blank: true
  validates :invite_code,
    presence: true,
    uniqueness: true,
    format: { with: INVITE_CODE_FORMAT, message: "harus berupa 6 karakter huruf dan angka" }

  # Menghasilkan kode acak 6 karakter yang selalu memadukan huruf dan angka.
  def self.generate_unique_invite_code
    loop do
      chars = Array.new(3) { LETTERS[SecureRandom.random_number(LETTERS.size)] } +
              Array.new(3) { DIGITS[SecureRandom.random_number(DIGITS.size)] }
      candidate = chars.shuffle(random: SecureRandom).join
      break candidate unless exists?(invite_code: candidate)
    end
  end

  def regenerate_invite_code!
    update!(invite_code: self.class.generate_unique_invite_code)
  end

  def leads
    users.merge(TeamMembership.leads)
  end

  def lead?(user)
    return false if user.nil?

    if team_memberships.loaded?
      team_memberships.any? { |membership| membership.user_id == user.id && membership.lead? }
    elsif user.team_memberships.loaded?
      user.lead_of?(self)
    else
      team_memberships.exists?(user_id: user.id, role: "lead")
    end
  end

  def active_members_with_avatars
    loaded_memberships = team_memberships.eager_load(user: { avatar_attachment: :blob }).to_a
    association(:team_memberships).target = loaded_memberships

    loaded_memberships
      .filter_map { |membership| membership.user if membership.user&.active? }
      .sort_by { |user| [ user.full_name.to_s, user.id ] }
  end

  private
    def assign_invite_code
      self.invite_code = self.class.generate_unique_invite_code if invite_code.blank?
    end
end
