require "test_helper"

# Fluxo de controle NOSSO do Projects::TasksController (Fatia 2.3): CRUD inline sob o
# projeto, unicidade por projeto (Q44), isolamento via projeto alheio (Q23 → 404) e o
# JSON (Q73). Testamos o fluxo, não a view Turbo Stream string a string.
class TasksTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = sign_in_as("dono@example.com")
    @project = @user.projects.create!(name: "Projeto")
  end

  # --- CRUD inline básico ------------------------------------------------------

  test "create adiciona uma task ao projeto (fluxo inline)" do
    assert_difference -> { @project.tasks.count }, +1 do
      post project_tasks_path(@project), params: { task: { name: "Design" } }
    end
    assert_response :redirect
    assert @project.tasks.exists?(name: "Design")
  end

  test "create com Turbo Stream re-renderiza a seção" do
    post project_tasks_path(@project),
      params: { task: { name: "Design" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "project_tasks", response.body
    assert @project.tasks.exists?(name: "Design")
  end

  test "update renomeia a task" do
    task = @project.tasks.create!(name: "Velho", user: @user)

    patch task_path(task), params: { task: { name: "Novo" } }
    assert_response :redirect
    assert_equal "Novo", task.reload.name
  end

  test "destroy remove a task" do
    task = @project.tasks.create!(name: "Some", user: @user)

    assert_difference -> { @project.tasks.count }, -1 do
      delete task_path(task)
    end
  end

  test "archival arquiva e desarquiva a task" do
    task = @project.tasks.create!(name: "Alvo", user: @user)

    post task_archival_path(task)
    assert task.reload.archived?

    delete task_archival_path(task)
    assert_not task.reload.archived?
  end

  # --- Unicidade por projeto (Q44) --------------------------------------------

  test "nome duplicado no mesmo projeto não cria (422 inline)" do
    @project.tasks.create!(name: "Design", user: @user)

    assert_no_difference -> { @project.tasks.count } do
      post project_tasks_path(@project),
        params: { task: { name: "Design" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :unprocessable_entity
  end

  test "MESMO nome em projetos diferentes é permitido" do
    outro = @user.projects.create!(name: "Outro")
    @project.tasks.create!(name: "Design", user: @user)

    assert_difference -> { outro.tasks.count }, +1 do
      post project_tasks_path(outro), params: { task: { name: "Design" } }
    end
  end

  # --- Isolamento via projeto alheio (Q23) ------------------------------------

  test "criar task em projeto de outra conta dá 404" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    post project_tasks_path(alheio), params: { task: { name: "Invasora" } }
    assert_response :not_found
  end

  test "editar task de outra conta dá 404 (rota rasa)" do
    outro = create_user(email: "outro@example.com")
    projeto_alheio = outro.projects.create!(name: "Alheio")
    task_alheia = projeto_alheio.tasks.create!(name: "Alheia", user: outro)

    patch task_path(task_alheia), params: { task: { name: "Invadida" } }
    assert_response :not_found
    assert_equal "Alheia", task_alheia.reload.name
  end

  private
    def sign_in_as(email)
      user = User.create!(email: email)
      perform_enqueued_jobs { post sign_in_path, params: { email: email } }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post sign_in_session_path, params: { code: code }
      user
    end
end
