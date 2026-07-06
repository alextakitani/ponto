class CreateClockifyImports < ActiveRecord::Migration[8.1]
  def change
    create_table :clockify_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :clients_created, null: false, default: 0
      t.integer :projects_created, null: false, default: 0
      t.integer :tasks_created, null: false, default: 0
      t.integer :tags_created, null: false, default: 0
      t.integer :time_entries_created, null: false, default: 0
      t.text :error_message
      t.boolean :files_purged, null: false, default: false

      t.timestamps
    end
  end
end
