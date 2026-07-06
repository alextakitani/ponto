class AddNameNormalizedToCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :name_normalized, :string, null: false
    add_column :projects, :name_normalized, :string, null: false
    add_column :tasks, :name_normalized, :string, null: false
    add_column :tags, :name_normalized, :string, null: false

    remove_index :clients, %i[user_id name]
    remove_index :projects, %i[user_id name]
    remove_index :tasks, %i[project_id name]
    remove_index :tags, %i[user_id name]

    add_index :clients, %i[user_id name_normalized], unique: true
    add_index :projects, %i[user_id name_normalized], unique: true
    add_index :tasks, %i[project_id name_normalized], unique: true
    add_index :tags, %i[user_id name_normalized], unique: true

    add_index :clients, :name_normalized
    add_index :projects, :name_normalized
    add_index :tasks, :name_normalized
    add_index :tags, :name_normalized
  end
end
