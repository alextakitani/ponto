class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true, index: true
      # `name` é criptografado (Q25c, deterministic) — o banco guarda o ciphertext.
      # É `text` porque o ciphertext do AR Encryption é bem maior que o valor cru.
      t.text :name, null: false
      # rate_cents nulável = cliente sem taxa (legítimo — Q2/Q15). Moeda mora aqui (Q42).
      t.integer :rate_cents
      t.string :currency, null: false, default: "BRL"
      t.text :note
      # Soft delete (Q7) — sem default_scope, scopes explícitos (concern Archivable).
      t.datetime :archived_at

      t.timestamps
    end

    # Nome ÚNICO por usuário, INCLUINDO arquivados (Q44 — sem condição de archived_at).
    # Funciona sobre o CIPHERTEXT deterministic: o mesmo nome cifra pro mesmo blob,
    # então o índice único pega a colisão no banco.
    add_index :clients, %i[user_id name], unique: true
  end
end
