class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :label
      # Escopo do token (decisões §3 "escopado por método HTTP"):
      #   read  -> só GET/HEAD   |   write -> qualquer método
      t.string :permission, null: false, default: "read"
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
  end
end
