# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_03_120100) do
  create_table "access_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.text "note"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_access_requests_on_email"
  end

  create_table "access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label"
    t.datetime "last_used_at"
    t.string "permission", default: "read", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token"], name: "index_access_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.text "name", null: false
    t.text "note"
    t.integer "rate_cents"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "archived_at"
    t.integer "client_id"
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.integer "rate_cents"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["user_id", "name"], name: "index_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sign_in_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sign_in_codes_on_expires_at"
    t.index ["user_id"], name: "index_sign_in_codes_on_user_id"
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "time_entry_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "time_entry_id"], name: "index_taggings_on_tag_id_and_time_entry_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["time_entry_id"], name: "index_taggings_on_time_entry_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.text "name", null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id", "name"], name: "index_tasks_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.boolean "billable", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "BRL", null: false
    t.text "description"
    t.datetime "ended_at"
    t.integer "project_id"
    t.integer "rate_cents"
    t.datetime "started_at", null: false
    t.integer "task_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["project_id"], name: "index_time_entries_on_project_id"
    t.index ["task_id"], name: "index_time_entries_on_task_id"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
    t.index ["user_id"], name: "index_time_entries_running_per_user", unique: true, where: "ended_at IS NULL"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.datetime "suspended_at"
    t.string "time_zone", default: "America/Sao_Paulo", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "clients", "users"
  add_foreign_key "projects", "clients"
  add_foreign_key "projects", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sign_in_codes", "users"
  add_foreign_key "taggings", "tags"
  add_foreign_key "taggings", "time_entries"
  add_foreign_key "tags", "users"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users"
  add_foreign_key "time_entries", "projects"
  add_foreign_key "time_entries", "tasks", on_delete: :nullify
  add_foreign_key "time_entries", "users"
end
