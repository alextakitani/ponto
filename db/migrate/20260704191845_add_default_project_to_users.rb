class AddDefaultProjectToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :default_project, foreign_key: { to_table: :projects, on_delete: :nullify }
  end
end
