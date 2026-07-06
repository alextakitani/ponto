# Projects (Fatia 2.3) — sub-bucket do Client na hierarquia Client→Project→Task.
# Toda coluna respeita o isolamento por bolha (Q23): `user_id` NN + escopo em toda
# query. `client_id` é NULÁVEL (Q2: projeto sem cliente é legítimo). `rate_cents` é
# OVERRIDE opcional da rate do cliente (Q22). `color` NN (paleta fixa — Q52).
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      # client_id NULÁVEL (Q2). FK garante integridade; a validação custom no model
      # exige que o cliente seja do MESMO user (a FK não sabe de bolhas).
      t.references :client, null: true, foreign_key: true
      t.text :name, null: false
      t.string :color, null: false            # hex #RRGGBB da paleta fixa (Q52)
      t.integer :rate_cents                    # override nulável (Q22); nula = herda
      t.datetime :archived_at                  # soft delete (Q7)

      t.timestamps
    end

    # Nome ÚNICO por user, INCLUINDO arquivados (Q44). Substituído por
    # name_normalized na migração de Nameable.
    add_index :projects, [ :user_id, :name ], unique: true
  end
end
