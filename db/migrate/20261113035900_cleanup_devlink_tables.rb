class CleanupDevlinkTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :click_events if table_exists?(:click_events)
    drop_table :links if table_exists?(:links)

    if column_exists?(:users, :username)
      remove_index :users, :username if index_exists?(:users, :username)
      remove_column :users, :username
      remove_column :users, :display_name
      remove_column :users, :bio
      remove_column :users, :theme
    end

    execute "DELETE FROM sessions"
    execute "DELETE FROM users"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
