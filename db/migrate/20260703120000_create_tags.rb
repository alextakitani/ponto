class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.datetime :archived_at

      t.timestamps
    end

    add_index :tags, [ :user_id, :name ], unique: true
  end
end
