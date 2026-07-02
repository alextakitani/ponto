# TimeEntries (Fatia 3.1) — sessões atômicas do tracker. Toda entry vive na bolha do
# `user` (Q23). `project_id` é NULÁVEL (Q15: timer solto é legítimo); `task_id`
# opcional, sempre subordinada ao projeto (validado no model). `rate_cents`/`currency`
# são SNAPSHOT histórico (Q10/Q11), recarimbados quando o projeto muda.
class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.references :task, null: true, foreign_key: { on_delete: :nullify }
      t.text :description
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :rate_cents
      t.string :currency, null: false, default: "BRL"
      t.boolean :billable, null: false, default: true

      t.timestamps
    end

    add_index :time_entries, :user_id,
      unique: true,
      where: "ended_at IS NULL",
      name: "index_time_entries_running_per_user"
  end
end
