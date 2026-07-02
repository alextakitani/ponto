class AddAdminFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, null: false, default: false
    add_column :users, :suspended_at, :datetime
    add_column :users, :time_zone, :string, null: false, default: "America/Sao_Paulo"
  end
end
