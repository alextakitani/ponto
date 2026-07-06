require "test_helper"

# Fluxo de controle NOSSO do ProjectsController (Fatia 2.3): CRUD, isolamento por
# bolha (Q23 — inclusive REJEITAR client_id de outra conta!), rate efetiva na tela,
# cor auto-atribuída, colisão-com-arquivado (Q44) e o hard-delete restrito do Client
# (Q7) pela via web. Não testamos view string a string nem CRUD de framework.
class ProjectsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = sign_in_as("dono@example.com")
  end

  # --- CRUD feliz + cor auto-atribuída ----------------------------------------

  test "index lista só os projetos ativos do user por padrão" do
    @user.projects.create!(name: "Ativo")
    arquivado = @user.projects.create!(name: "Arquivado")
    arquivado.archive!

    get projects_path
    assert_response :success
    assert_select "body", text: /Ativo/
    assert_select "body", { text: /Arquivado/, count: 0 }
  end

  test "create cria o projeto com cor da paleta e sem cliente (Q2)" do
    assert_difference -> { @user.projects.count }, +1 do
      post projects_path, params: { project: { name: "Solo", color: Project::PALETTE.first } }
    end
    project = @user.projects.find_by!(name: "Solo")
    assert_nil project.client_id
    assert_includes Project::PALETTE, project.color
    assert_redirected_to projects_path
  end

  test "create sem cor usa a auto-atribuída (menos usada) do model" do
    post projects_path, params: { project: { name: "SemCor" } }
    project = @user.projects.find_by!(name: "SemCor")
    assert_equal Project::PALETTE.first, project.color
  end

  test "create com cor inválida re-renderiza 422" do
    assert_no_difference -> { @user.projects.count } do
      post projects_path, params: { project: { name: "X", color: "roxo" } }
    end
    assert_response :unprocessable_entity
  end

  # --- Rate efetiva na tela (Q22) ---------------------------------------------

  test "index mostra a rate herdada do cliente marcada como 'do cliente'" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 15000)
    @user.projects.create!(name: "Herdeiro", client: client) # sem override → herda

    get projects_path
    assert_response :success
    assert_match(/do cliente/, response.body)
    assert_match(/150,00/, response.body)
  end

  test "create com override de rate pt-BR grava rate_cents" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000)
    post projects_path, params: {
      project: { name: "Override", client_id: client.id, rate: "200,00", color: Project::PALETTE.first }
    }
    project = @user.projects.find_by!(name: "Override")
    assert_equal 20000, project.rate_cents
    assert_equal 20000, project.effective_rate_cents
  end

  # --- Isolamento por bolha (Q23) ---------------------------------------------

  test "index não mostra projetos de outra conta" do
    outro = create_user(email: "outro@example.com")
    outro.projects.create!(name: "AlheioSecreto")

    get projects_path
    assert_select "body", { text: /AlheioSecreto/, count: 0 }
  end

  test "show de projeto de outra conta dá 404" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    get project_path(alheio)
    assert_response :not_found
  end

  test "create REJEITA client_id de outra conta (isolamento Q23)" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.clients.create!(name: "ClienteAlheio")

    assert_no_difference -> { @user.projects.count } do
      post projects_path, params: {
        project: { name: "Invasor", client_id: alheio.id, color: Project::PALETTE.first }
      }
    end
    assert_response :unprocessable_entity
  end

  # --- Colisão com arquivado (Q44) --------------------------------------------

  test "criar com nome de um projeto ARQUIVADO mostra a mensagem de desarquivar" do
    arquivado = @user.projects.create!(name: "Site")
    arquivado.archive!

    assert_no_difference -> { @user.projects.count } do
      post projects_path, params: { project: { name: "Site", color: Project::PALETTE.first } }
    end
    assert_response :unprocessable_entity
    assert_match(/arquivado/i, response.body)
    assert_match(/desarquiv/i, response.body)
  end

  # --- Archive / unarchive (Q7) -----------------------------------------------

  test "archival cria e remove o arquivamento" do
    project = @user.projects.create!(name: "Alvo")

    post project_archival_path(project)
    assert project.reload.archived?

    delete project_archival_path(project)
    assert_not project.reload.archived?
  end

  test "POST default com projeto próprio seta o padrão" do
    project = @user.projects.create!(name: "Padrão")

    post project_default_path(project)

    assert_redirected_to projects_path
    assert_equal project, @user.reload.default_project
  end

  test "POST default com projeto de outro user dá 404" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    assert_no_changes -> { @user.reload.default_project_id } do
      post project_default_path(alheio)
    end

    assert_response :not_found
  end

  test "DELETE default limpa o padrão" do
    project = @user.projects.create!(name: "Padrão")
    @user.update!(default_project: project)

    delete project_default_path(project)

    assert_redirected_to projects_path
    assert_nil @user.reload.default_project_id
  end

  test "definir padrão via turbo_stream atualiza a barra do timer (sem timer rodando)" do
    project = @user.projects.create!(name: "Padrão")

    post project_default_path(project), as: :turbo_stream

    assert_response :success
    # reescreve a lista de projetos E a barra do timer (pra o select pré-selecionar)
    assert_match %r{turbo-stream action="update" target="projects_list"}, response.body
    assert_match %r{turbo-stream action="replace" target="timer_bar"}, response.body
  end

  test "definir padrão com timer RODANDO não toca a barra do timer" do
    project = @user.projects.create!(name: "Padrão")
    @user.time_entries.create!(description: "rodando", started_at: Time.current) # sem ended_at

    post project_default_path(project), as: :turbo_stream

    assert_response :success
    assert_match %r{target="projects_list"}, response.body
    # a barra NÃO é substituída — o cronômetro em andamento fica intocado
    assert_no_match %r{target="timer_bar"}, response.body
  end

  # Regressão: mudar o padrão NÃO pode reordenar a lista. A ordem tem que ser a MESMA
  # da index (Nameable.alphabetical).
  test "definir padrão mantém a ordem alfabética da lista estável" do
    %w[Charlie alpha Bravo].each { |n| @user.projects.create!(name: n) }
    expected = %w[alpha Bravo Charlie] # forma normalizada, como a index

    get projects_path
    index_order = css_select("#projects_list a").map(&:text).select { |t| expected.include?(t) }
    assert_equal expected, index_order, "sanidade: a index já ordena assim"

    post project_default_path(@user.projects.find_by(name: "Charlie")), as: :turbo_stream

    stream_order = css_select("turbo-stream[target=projects_list] a")
      .map(&:text).select { |t| expected.include?(t) }
    assert_equal expected, stream_order, "a ordem após mudar o padrão deve ser idêntica à index"
  end

  # --- Hard-delete restrito do Client pela via web (Q7) -----------------------

  test "deletar cliente COM projeto falha com mensagem amigável (restrict Q7)" do
    client = @user.clients.create!(name: "ComProjeto")
    @user.projects.create!(name: "P1", client: client)

    assert_no_difference -> { @user.clients.count } do
      delete client_path(client)
    end
    follow_redirect!
    assert_match(/arquive/i, response.body)
  end

  # --- Filtro por cliente ------------------------------------------------------

  test "filtro por cliente lista só os projetos daquele cliente" do
    acme = @user.clients.create!(name: "Acme")
    globex = @user.clients.create!(name: "Globex")
    @user.projects.create!(name: "ProjetoAcme", client: acme)
    @user.projects.create!(name: "ProjetoGlobex", client: globex)

    get projects_path(client_id: acme.id)
    assert_select "body", text: /ProjetoAcme/
    assert_select "body", { text: /ProjetoGlobex/, count: 0 }
  end
end
