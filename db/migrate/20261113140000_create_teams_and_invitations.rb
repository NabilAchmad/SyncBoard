class CreateTeamsAndInvitations < ActiveRecord::Migration[8.1]
  class MigrationUser < ApplicationRecord
    self.table_name = "users"
  end

  class MigrationTeam < ApplicationRecord
    self.table_name = "teams"
  end

  class MigrationMembership < ApplicationRecord
    self.table_name = "team_memberships"
  end

  class MigrationProject < ApplicationRecord
    self.table_name = "projects"
  end

  def up
    create_table :teams do |t|
      t.string :name, null: false
      t.string :invite_code, null: false
      t.text :description
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :teams, :invite_code, unique: true

    create_table :team_memberships do |t|
      t.references :team, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false, default: "member"
      t.datetime :joined_at, null: false

      t.timestamps
    end
    add_index :team_memberships, %i[team_id user_id], unique: true

    add_reference :projects, :team, null: true, foreign_key: { on_delete: :cascade }
    add_reference :sessions, :current_team, null: true, foreign_key: { to_table: :teams, on_delete: :nullify }

    # Kelompokkan proyek lama ke tim pemilik aslinya; akun lain tetap kosong hingga masuk lewat kode undangan 6 karakter.
    owner_ids = MigrationProject.distinct.pluck(:owner_id)
    owner_ids.each do |owner_id|
      owner = MigrationUser.find_by(id: owner_id)
      next unless owner

      first_name = owner.full_name.to_s.split(/\s+/).first.presence || "Workspace"
      team = MigrationTeam.create!(
        name: "Tim #{first_name}",
        invite_code: generate_unique_code,
        owner_id: owner.id
      )

      MigrationMembership.create!(
        team_id: team.id,
        user_id: owner.id,
        role: "lead",
        joined_at: Time.current
      )

      MigrationProject.where(owner_id: owner.id).update_all(team_id: team.id)
    end

    change_column_null :projects, :team_id, false
    remove_index :projects, :key if index_exists?(:projects, :key)
    add_index :projects, %i[team_id key], unique: true
  end

  def down
    remove_index :projects, %i[team_id key] if index_exists?(:projects, %i[team_id key])
    add_index :projects, :key, unique: true unless index_exists?(:projects, :key)
    remove_reference :sessions, :current_team, foreign_key: { to_table: :teams }
    remove_reference :projects, :team, foreign_key: true
    drop_table :team_memberships
    drop_table :teams
  end

  private
    def generate_unique_code
      letters = %w[A B C D E F G H J K L M N P Q R S T U V W X Y Z]
      digits = %w[2 3 4 5 6 7 8 9]

      loop do
        chars = Array.new(3) { letters[SecureRandom.random_number(letters.size)] } +
                Array.new(3) { digits[SecureRandom.random_number(digits.size)] }
        candidate = chars.shuffle(random: SecureRandom).join
        break candidate unless MigrationTeam.exists?(invite_code: candidate)
      end
    end
end
