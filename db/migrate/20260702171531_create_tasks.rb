# Tasks (Fatia 2.3) — sub-bucket do Project (Q1). Carrega `user_id` DIRETO (isolamento
# Q23: escopa a bolha sem passar pelo project) além de `project_id`. Nome ÚNICO POR
# PROJETO (Q44: mesmo nome em projetos diferentes é OK).
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.text :name, null: false
      t.datetime :archived_at  # soft delete (Q7)

      t.timestamps
    end

    # Nome ÚNICO POR PROJETO, INCLUINDO arquivados (Q44). Escopo = project_id (não
    # user_id): a mesma task "Design" pode existir em projetos diferentes do user.
    add_index :tasks, [ :project_id, :name ], unique: true
  end
end
