require "test_helper"

# CRUD JSON de TimeEntry (Fatia 3.1). Testamos fluxo nosso: scope por user, ordem do
# index, snapshot, update sem stop implícito, erros em escalares e bearer read/write.
class TimeEntriesJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "entries@example.com")
    @project = @user.projects.create!(name: "Projeto", rate_cents: 15000)
    @task = @project.tasks.create!(name: "Design", user: @user)
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET index devolve só as entries do user em ordem decrescente de started_at" do
    older = @user.time_entries.create!(started_at: Time.utc(2026, 7, 1, 10), ended_at: Time.utc(2026, 7, 1, 11))
    newer = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 10), ended_at: Time.utc(2026, 7, 2, 11))
    other = create_user(email: "other-entries@example.com")
    other.time_entries.create!(started_at: Time.utc(2026, 7, 3, 10), ended_at: Time.utc(2026, 7, 3, 11))

    get time_entries_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_equal [ newer.id, older.id ], response.parsed_body.map { |entry| entry["id"] }
  end

  test "GET show devolve escalares calculados" do
    entry = @user.time_entries.create!(
      project: @project,
      task: @task,
      description: "Detalhe",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 30, 0)
    )

    get time_entry_path(entry), headers: bearer(@read), as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal entry.id, body["id"]
    assert_equal 5400, body["duration_seconds"]
    assert_equal 22500, body["billable_amount_cents"]
    assert_equal 15000, body["rate_cents"]
    assert_equal "BRL", body["currency"]
  end

  test "POST create cria entry manual com snapshot do projeto" do
    started_at = Time.utc(2026, 7, 2, 8, 0, 0)
    ended_at = Time.utc(2026, 7, 2, 10, 0, 0)
    tag = @user.tags.create!(name: "API")

    assert_difference -> { @user.time_entries.count }, +1 do
      post time_entries_path, headers: bearer(@write),
        params: {
          time_entry: {
            project_id: @project.id,
            task_id: @task.id,
            description: "Manual",
            started_at: started_at,
            ended_at: ended_at,
            tag_ids: [ tag.id ],
            new_tag_names: [ "Urgente" ]
          }
        },
        as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal 15000, body["rate_cents"]
    assert_equal "BRL", body["currency"]
    assert_equal 7200, body["duration_seconds"]
    assert_equal [ "API", "Urgente" ], @user.time_entries.order(:created_at).last.tags.map(&:name).sort
  end

  test "POST create inválido devolve 422 com errors" do
    now = Time.current

    assert_no_difference -> { @user.time_entries.count } do
      post time_entries_path, headers: bearer(@write),
        params: { time_entry: { started_at: now, ended_at: now } },
        as: :json
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body["errors"], "Fim deve ser maior que o início"
  end

  test "POST create com token read é rejeitado (401)" do
    assert_no_difference -> { @user.time_entries.count } do
      post time_entries_path, headers: bearer(@read),
        params: { time_entry: { started_at: Time.current, ended_at: Time.current + 1.hour } },
        as: :json
    end

    assert_response :unauthorized
  end

  test "PATCH update edita campos permitidos e mantém snapshot ao trocar rate do client" do
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 10000)
    first_project = @user.projects.create!(name: "A", client: client)
    second_project = @user.projects.create!(name: "B", rate_cents: 23000)
    first_task = first_project.tasks.create!(name: "Primeira", user: @user)
    second_task = second_project.tasks.create!(name: "Segunda", user: @user)
    entry = @user.time_entries.create!(
      project: first_project,
      task: first_task,
      started_at: Time.utc(2026, 7, 2, 8, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 9, 0, 0)
    )

    client.update!(rate_cents: 50000)

    patch time_entry_path(entry), headers: bearer(@write),
      params: {
        time_entry: {
          description: "Atualizada",
          project_id: second_project.id,
          task_id: second_task.id,
          billable: false,
          started_at: Time.utc(2026, 7, 2, 7, 30, 0),
          ended_at: Time.utc(2026, 7, 2, 9, 30, 0)
        }
      },
      as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal "Atualizada", body["description"]
    assert_equal second_project.id, body["project_id"]
    assert_equal second_task.id, body["task_id"]
    assert_equal 23000, body["rate_cents"]
    assert_equal "BRL", body["currency"]
    assert_equal false, body["billable"]
    assert_equal 7200, body["duration_seconds"]
  end

  test "PATCH update não permite parar entry rodando pela rota de CRUD" do
    entry = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 12, 0, 0))

    patch time_entry_path(entry), headers: bearer(@write),
      params: { time_entry: { ended_at: Time.utc(2026, 7, 2, 13, 0, 0), description: "Só descrição" } },
      as: :json

    assert_response :success
    assert_nil entry.reload.ended_at
    assert_equal "Só descrição", entry.description
  end

  test "DELETE destroy remove a entry do user" do
    entry = @user.time_entries.create!(started_at: Time.current - 1.hour, ended_at: Time.current)

    assert_difference -> { @user.time_entries.count }, -1 do
      delete time_entry_path(entry), headers: bearer(@write), as: :json
    end

    assert_response :no_content
  end

  test "não vê nem destrói entry de outra conta (404)" do
    other = create_user(email: "other-show@example.com")
    foreign = other.time_entries.create!(started_at: Time.current - 1.hour, ended_at: Time.current)

    get time_entry_path(foreign), headers: bearer(@read), as: :json
    assert_response :not_found

    delete time_entry_path(foreign), headers: bearer(@write), as: :json
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
