require "test_helper"

# Superfície JSON dos Projects (Q73) via Bearer AccessToken. NOSSA lógica: expõe
# ESCALARES (rate_cents/effective_rate_cents int|null + currency string — NUNCA Money
# cru, Q11), a rate efetiva JÁ resolvida (Q22), e o mapeamento verbo×permission do
# bearer se aplica (read faz GET; write faz POST; read NÃO faz POST). Show traz tasks.
class ProjectsJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ext@example.com")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET index devolve escalares e a rate efetiva resolvida (herança Q22)" do
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 15000)
    @user.projects.create!(name: "Herdeiro", client: client) # herda

    get projects_path, headers: bearer(@read), as: :json
    assert_response :success

    project = response.parsed_body.first
    assert_equal "Herdeiro", project["name"]
    assert_nil project["rate_cents"]                       # override nulo
    assert_equal 15000, project["effective_rate_cents"]    # herdada do cliente
    assert_equal "USD", project["effective_currency"]
    assert_kind_of Integer, project["effective_rate_cents"] # escalar, não Money
    assert project["color"].present?
    assert_equal false, project["default"]
  end

  test "GET index marca projeto padrão como boolean escalar" do
    default = @user.projects.create!(name: "Default")
    @user.update!(default_project: default)
    @user.projects.create!(name: "Outro")

    get projects_path, headers: bearer(@read), as: :json
    assert_response :success

    defaults = response.parsed_body.index_by { |project| project["name"] }
    assert_equal true, defaults["Default"]["default"]
    assert_equal false, defaults["Outro"]["default"]
  end

  test "POST default JSON com token write seta e devolve escalar" do
    project = @user.projects.create!(name: "Default")

    post project_default_path(project), headers: bearer(@write), as: :json

    assert_response :created
    assert_equal project.id, @user.reload.default_project_id
    assert_equal project.id, response.parsed_body["default_project_id"]
  end

  test "POST default JSON de outro user dá 404" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    post project_default_path(alheio), headers: bearer(@write), as: :json

    assert_response :not_found
    assert_nil @user.reload.default_project_id
  end

  test "DELETE default JSON limpa" do
    project = @user.projects.create!(name: "Default")
    @user.update!(default_project: project)

    delete project_default_path(project), headers: bearer(@write), as: :json

    assert_response :no_content
    assert_nil @user.reload.default_project_id
  end

  test "GET show traz as tasks ativas do projeto (array)" do
    project = @user.projects.create!(name: "ComTasks")
    project.tasks.create!(name: "Design", user: @user)

    get project_path(project), headers: bearer(@read), as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "ComTasks", body["name"]
    assert_equal [ "Design" ], body["tasks"].map { |t| t["name"] }
  end

  test "POST create com token write cria e devolve 201 com effective_rate resolvida" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000)

    assert_difference -> { @user.projects.count }, +1 do
      post projects_path, headers: bearer(@write),
        params: { project: { name: "Novo", client_id: client.id, rate_cents: 20000, color: Project::PALETTE.first } },
        as: :json
    end
    assert_response :created
    body = response.parsed_body
    assert_equal 20000, body["rate_cents"]
    assert_equal 20000, body["effective_rate_cents"]
    assert_equal "BRL", body["effective_currency"]
  end

  test "POST create com token READ é rejeitado (401 — verbo×permission)" do
    assert_no_difference -> { @user.projects.count } do
      post projects_path, headers: bearer(@read),
        params: { project: { name: "Barrado" } }, as: :json
    end
    assert_response :unauthorized
  end

  test "não vê projeto de outra conta pelo bearer (404 — isolamento Q23)" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    get project_path(alheio), headers: bearer(@read), as: :json
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
