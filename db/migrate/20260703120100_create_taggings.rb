class CreateTaggings < ActiveRecord::Migration[8.1]
  def change
    create_table :taggings do |t|
      t.references :tag, null: false, foreign_key: true, index: true
      t.references :time_entry, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :taggings, [ :tag_id, :time_entry_id ], unique: true
  end
end
