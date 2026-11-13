class AddEmployeeFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :full_name, :string, null: false
    add_column :users, :employee_code, :string, null: false
    add_column :users, :department, :string, null: false, default: "Engineering"
    add_column :users, :job_title, :string, null: false, default: "Staff"
    add_column :users, :phone, :string
    add_column :users, :role, :string, null: false, default: "employee"
    add_column :users, :active, :boolean, null: false, default: true

    add_index :users, :employee_code, unique: true
    add_index :users, :role
  end
end
