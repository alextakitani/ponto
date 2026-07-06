require "test_helper"

# Fluxo de controle NOSSO do ClientsController (Fatia 2.2): CRUD feliz, isolamento
# por bolha (Q23), archive/unarchive, a UX da colisão-com-arquivado (Q44) e a busca
# por nome via SQL normalizado. Não testamos view string a string nem o CRUD do
# framework.
class ClientsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = sign_in_as("dono@example.com")
  end

  # --- CRUD feliz -------------------------------------------------------------

  test "index lista só os clientes ativos do user por padrão" do
    ativo = @user.clients.create!(name: "Ativo")
    arquivado = @user.clients.create!(name: "Arquivado")
    arquivado.archive!

    get clients_path
    assert_response :success
    assert_select "body", text: /Ativo/
    assert_select "body", { text: /Arquivado/, count: 0 }
  end

  test "index com filtro de arquivados mostra os arquivados" do
    arquivado = @user.clients.create!(name: "Aposentado")
    arquivado.archive!

    get clients_path(archived: "1")
    assert_response :success
    assert_select "body", text: /Aposentado/
  end

  test "create cria o cliente do user logado" do
    assert_difference -> { @user.clients.count }, +1 do
      post clients_path, params: { client: { name: "Acme", currency: "BRL", rate_cents: 15000 } }
    end
    client = @user.clients.find_by!(name: "Acme")
    assert_equal 15000, client.rate_cents
    assert_redirected_to clients_path
  end

  test "create com nome inválido re-renderiza o form (não cria)" do
    assert_no_difference -> { @user.clients.count } do
      post clients_path, params: { client: { name: "", currency: "BRL" } }
    end
    assert_response :unprocessable_entity
  end

  # --- Rate pt-BR pelo fluxo real (regressão do 500 — locale default pt-BR) ----
  # SEM Accept-Language → locale default :pt-BR. O usuário digita "150,00" (o formato
  # que o placeholder anuncia). Antes: money-rails rejeitava e o render estourava
  # I18n::MissingTranslationData → 500. Agora: 302 e cliente com 15000 cents.
  test "create com rate '150,00' (pt-BR default) cria e não dá 500" do
    assert_difference -> { @user.clients.count }, +1 do
      post clients_path, params: { client: { name: "PtBr", currency: "BRL", rate: "150,00" } }
    end
    assert_redirected_to clients_path
    assert_equal 15000, @user.clients.find_by!(name: "PtBr").rate_cents
  end

  # Ciclo display -> submit idempotente: o valor re-exibido no form (pt-BR "150,00")
  # reenviado num PATCH não corrompe a rate.
  test "edit reexibe a rate em pt-BR e o resubmit é idempotente" do
    client = @user.clients.create!(name: "Idem", currency: "BRL", rate_cents: 15000)

    get edit_client_path(client)
    assert_response :success
    assert_match(/150,00/, response.body)

    patch client_path(client), params: { client: { name: "Idem", currency: "BRL", rate: "150,00" } }
    assert_redirected_to clients_path
    assert_equal 15000, client.reload.rate_cents
  end

  test "create com rate não-parseável re-renderiza 422 com a mensagem PT" do
    assert_no_difference -> { @user.clients.count } do
      post clients_path, params: { client: { name: "Ruim", currency: "BRL", rate: "abc" } }
    end
    assert_response :unprocessable_entity
    assert_match(/não é um valor válido/, response.body)
  end

  test "update edita o cliente" do
    client = @user.clients.create!(name: "Velho")

    patch client_path(client), params: { client: { name: "Novo" } }
    assert_redirected_to clients_path
    assert_equal "Novo", client.reload.name
  end

  test "destroy hard-deleta o cliente" do
    client = @user.clients.create!(name: "Some")

    assert_difference -> { @user.clients.count }, -1 do
      delete client_path(client)
    end
    assert_not Client.exists?(client.id)
  end

  # --- Isolamento por bolha (Q23) ---------------------------------------------

  test "index não mostra clientes de outra conta" do
    outro = create_user(email: "outro@example.com")
    outro.clients.create!(name: "AlheioSecreto")

    get clients_path
    assert_select "body", { text: /AlheioSecreto/, count: 0 }
  end

  test "show de cliente de outra conta dá 404 (fora do escopo)" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.clients.create!(name: "Alheio")

    get client_path(alheio)
    assert_response :not_found
  end

  test "update de cliente de outra conta dá 404 (fora do escopo)" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.clients.create!(name: "Alheio")

    patch client_path(alheio), params: { client: { name: "Invadido" } }
    assert_response :not_found
    assert_equal "Alheio", alheio.reload.name
  end

  # --- Archive / unarchive (Q7) -----------------------------------------------

  test "archival cria e remove o arquivamento" do
    client = @user.clients.create!(name: "Alvo")

    post client_archival_path(client)
    assert client.reload.archived?

    delete client_archival_path(client)
    assert_not client.reload.archived?
  end

  # --- Colisão com arquivado: UX específica (Q44) -----------------------------

  test "criar com nome de um cliente ARQUIVADO mostra a mensagem de desarquivar" do
    arquivado = @user.clients.create!(name: "Acme")
    arquivado.archive!

    assert_no_difference -> { @user.clients.count } do
      post clients_path, params: { client: { name: "Acme", currency: "BRL" } }
    end
    assert_response :unprocessable_entity
    assert_match(/arquivado/i, response.body)
    assert_match(/desarquiv/i, response.body)
  end

  # --- Busca por nome ----------------------------------------------------------

  test "busca por nome acha por substring case-insensitive e sem acento" do
    @user.clients.create!(name: "Padaria do João")
    @user.clients.create!(name: "Mercado Central")

    get clients_path(q: "joao")
    assert_select "body", text: /Padaria do João/
    assert_select "body", { text: /Mercado Central/, count: 0 }
  end
end
