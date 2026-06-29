class CreateSignInCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_codes do |t|
      t.references :user, null: false, foreign_key: true
      # Guardamos só o digest do código de 6 dígitos (uso único, expira em 15 min).
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at

      t.timestamps
    end

    add_index :sign_in_codes, :expires_at
  end
end
