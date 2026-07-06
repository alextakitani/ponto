class AddAccentToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :accent, :string, null: false, default: "teal"
  end
end
