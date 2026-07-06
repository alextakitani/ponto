require "test_helper"

# Timer singular (Fatia 3.1) via Bearer AccessToken. Testamos a lógica NOSSA:
# singleton por user, GET retorna entry rodando ou null, start conflita com 409,
# stop é explícito, tokens read/write respeitam verbo e o isolamento por bolha não
# vaza o timer alheio.
class TimerJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "timer@example.com")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET /timer devolve null quando o user não tem timer rodando" do
    get timer_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_nil response.parsed_body
  end

  test "GET /timer devolve a entry rodando do user em escalares" do
    entry = @user.time_entries.create!(
      description: "Rodando",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0)
    )

    get timer_path, headers: bearer(@read), as: :json

    assert_response :success
    assert_equal entry.id, response.parsed_body["id"]
    assert_nil response.parsed_body["ended_at"]
    assert_nil response.parsed_body["duration_seconds"]
    assert_nil response.parsed_body["billable_amount_cents"]
  end

  test "POST /timer com token write cria um timer rodando" do
    project = @user.projects.create!(name: "Projeto", rate_cents: 12000)
    task = project.tasks.create!(name: "Design", user: @user)

    assert_difference -> { @user.time_entries.count }, +1 do
      post timer_path, headers: bearer(@write),
        params: { timer: { project_id: project.id, task_id: task.id, description: "Em andamento" } },
        as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal project.id, body["project_id"]
    assert_equal task.id, body["task_id"]
    assert_equal "Em andamento", body["description"]
    assert_nil body["ended_at"]
  end

  test "POST /timer JSON com project_id explícito respeita o projeto enviado" do
    default = @user.projects.create!(name: "Default")
    explicit = @user.projects.create!(name: "Explícito")
    @user.update!(default_project: default)

    post timer_path, headers: bearer(@write),
      params: { timer: { project_id: explicit.id, description: "Outro projeto" } },
      as: :json

    assert_response :created
    assert_equal explicit.id, response.parsed_body["project_id"]
    assert_equal explicit.id, @user.time_entries.find_by!(ended_at: nil).project_id
  end

  test "POST /timer JSON com project_id nil explícito não usa o projeto padrão" do
    default = @user.projects.create!(name: "Default")
    @user.update!(default_project: default)

    post timer_path, headers: bearer(@write),
      params: { timer: { project_id: nil, description: "Sem projeto explícito" } },
      as: :json

    assert_response :created
    assert_nil response.parsed_body["project_id"]
    assert_nil @user.time_entries.find_by!(ended_at: nil).project_id
  end

  test "POST /timer com token read é rejeitado (401)" do
    assert_no_difference -> { @user.time_entries.count } do
      post timer_path, headers: bearer(@read), params: { timer: { description: "Barrado" } }, as: :json
    end

    assert_response :unauthorized
  end

  test "POST /timer conflita com 409 quando já há um rodando" do
    @user.time_entries.create!(started_at: Time.current)

    assert_no_difference -> { @user.time_entries.count } do
      post timer_path, headers: bearer(@write), params: { timer: { description: "Segundo" } }, as: :json
    end

    assert_response :conflict
    assert_equal "timer já está rodando", response.parsed_body["error"]
  end

  test "DELETE /timer para o timer rodando e devolve a entry finalizada" do
    entry = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 12, 0, 0))

    travel_to Time.utc(2026, 7, 2, 12, 45, 0) do
      delete timer_path, headers: bearer(@write), as: :json
    end

    assert_response :success
    assert_equal entry.id, response.parsed_body["id"]
    assert_equal 2700, response.parsed_body["duration_seconds"]
    assert_equal entry.reload.ended_at.as_json, response.parsed_body["ended_at"]
  end

  test "DELETE /timer apaga a entry de duração zero" do
    entry = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 12, 0, 0))

    travel_to entry.started_at do
      assert_difference -> { TimeEntry.count }, -1 do
        delete timer_path, headers: bearer(@write), as: :json
      end
    end

    assert_response :no_content
  end

  test "DELETE /timer sem timer rodando devolve 404" do
    delete timer_path, headers: bearer(@write), as: :json

    assert_response :not_found
    assert_equal "timer não encontrado", response.parsed_body["error"]
  end

  test "timers de users diferentes são independentes" do
    other = create_user(email: "other-timer@example.com")
    other_write = other.access_tokens.create!(permission: "write")

    post timer_path, headers: bearer(@write), as: :json
    assert_response :created

    post timer_path, headers: bearer(other_write), as: :json
    assert_response :created

    assert_equal 1, @user.time_entries.where(ended_at: nil).count
    assert_equal 1, other.time_entries.where(ended_at: nil).count
  end

  test "timer de outro user não vaza: GET devolve null e DELETE devolve 404" do
    other = create_user(email: "other@example.com")
    other.time_entries.create!(started_at: Time.current)

    get timer_path, headers: bearer(@read), as: :json
    assert_response :success
    assert_nil response.parsed_body

    delete timer_path, headers: bearer(@write), as: :json
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
