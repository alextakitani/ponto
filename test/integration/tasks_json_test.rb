require "test_helper"

# Superfície JSON das Tasks (Q73) via Bearer, nas rotas aninhadas/rasas. NOSSA lógica:
# escalares, verbo×permission e isolamento por bolha (Q23).
class TasksJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ext@example.com")
    @project = @user.projects.create!(name: "Projeto")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET index (aninhado) devolve as tasks do projeto em escalares" do
    @project.tasks.create!(name: "Design", user: @user)

    get project_tasks_path(@project), headers: bearer(@read), as: :json
    assert_response :success
    task = response.parsed_body.first
    assert_equal "Design", task["name"]
    assert_equal @project.id, task["project_id"]
  end

  test "POST create (aninhado) com write cria e devolve 201" do
    assert_difference -> { @project.tasks.count }, +1 do
      post project_tasks_path(@project), headers: bearer(@write),
        params: { task: { name: "Nova" } }, as: :json
    end
    assert_response :created
    assert_equal "Nova", response.parsed_body["name"]
  end

  test "POST create com token READ é rejeitado (401)" do
    assert_no_difference -> { @project.tasks.count } do
      post project_tasks_path(@project), headers: bearer(@read),
        params: { task: { name: "Barrada" } }, as: :json
    end
    assert_response :unauthorized
  end

  test "não cria task em projeto de outra conta pelo bearer (404)" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    post project_tasks_path(alheio), headers: bearer(@write),
      params: { task: { name: "Invasora" } }, as: :json
    assert_response :not_found
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
