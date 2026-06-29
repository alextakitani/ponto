class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :label
      # Métodos HTTP que este token pode usar (ex.: "GET,POST"). Decisões §3.
      t.string :http_methods, null: false, default: "GET"
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :access_tokens, :token, unique: true
  end
end
