class Session < ApplicationRecord
  belongs_to :user
  belongs_to :current_team, class_name: "Team", optional: true
end
