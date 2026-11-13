class SetupSyncboardSchema < ActiveRecord::Migration[8.1]
  def up
    drop_table :attendances, if_exists: true
    drop_table :company_settings, if_exists: true

    change_column_default :users, :role, from: "employee", to: "member"
    execute <<~SQL.squish
      UPDATE users SET role = 'lead' WHERE role = 'hr_admin'
    SQL
    execute <<~SQL.squish
      UPDATE users SET role = 'member' WHERE role = 'employee'
    SQL

    create_table :projects do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "active"

      t.timestamps
    end
    add_index :projects, :key, unique: true

    create_table :meetings do |t|
      t.references :project, null: false, foreign_key: true
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :room_code, null: false
      t.text :agenda
      t.string :status, null: false, default: "live"
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.text :transcript_text
      t.text :summary_text
      t.datetime :approved_at
      t.text :rejection_reason

      t.timestamps
    end
    add_index :meetings, :room_code, unique: true
    add_index :meetings, :status

    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.references :source_meeting, null: true, foreign_key: { to_table: :meetings, on_delete: :nullify }
      t.string :code, null: false
      t.string :title, null: false
      t.text :description
      t.string :column_status, null: false, default: "todo"
      t.string :priority, null: false, default: "medium"
      t.integer :position, null: false, default: 0
      t.date :due_date

      t.timestamps
    end
    add_index :tasks, [ :project_id, :column_status, :position ]
    add_index :tasks, [ :project_id, :code ], unique: true

    create_table :meeting_messages do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.string :kind, null: false, default: "chat"

      t.timestamps
    end
    add_index :meeting_messages, [ :meeting_id, :created_at ]

    create_table :meeting_action_items do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :target_task, null: true, foreign_key: { to_table: :tasks, on_delete: :nullify }
      t.references :assignee, null: true, foreign_key: { to_table: :users }
      t.string :action_type, null: false, default: "create_task"
      t.string :title, null: false
      t.text :description
      t.string :target_column, null: false, default: "todo"
      t.string :priority, null: false, default: "medium"
      t.boolean :selected, null: false, default: true
      t.boolean :applied, null: false, default: false

      t.timestamps
    end

    create_table :activity_logs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :meeting, null: true, foreign_key: { on_delete: :nullify }
      t.string :summary, null: false

      t.timestamps
    end
    add_index :activity_logs, [ :project_id, :created_at ]
  end

  def down
    drop_table :activity_logs, if_exists: true
    drop_table :meeting_action_items, if_exists: true
    drop_table :meeting_messages, if_exists: true
    drop_table :tasks, if_exists: true
    drop_table :meetings, if_exists: true
    drop_table :projects, if_exists: true
    change_column_default :users, :role, from: "member", to: "employee"
  end
end
