require "test_helper"

# Superfície JSON dos Clients (Q73) autenticada por Bearer AccessToken. Testamos
# NOSSA lógica: o JSON expõe ESCALARES (rate_cents int + currency string, NUNCA
# objeto Money cru — Q11) e o mapeamento verbo×permission do bearer se aplica ao
# recurso novo (read faz GET; write faz POST; read NÃO faz POST).
class ClientsJsonTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ext@example.com")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "GET index com token read devolve JSON de escalares (sem Money cru)" do
    @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 15000)

    get clients_path, headers: bearer(@read), as: :json
    assert_response :success

    body = response.parsed_body
    client = body.first
    assert_equal "Acme", client["name"]
    assert_equal 15000, client["rate_cents"]
    assert_equal "BRL", client["currency"]
    # NUNCA serializar Money cru: rate_cents é um inteiro, não um hash.
    assert_kind_of Integer, client["rate_cents"]
  end

  test "GET show devolve o cliente em JSON" do
    client = @user.clients.create!(name: "Acme")

    get client_path(client), headers: bearer(@read), as: :json
    assert_response :success
    assert_equal "Acme", response.parsed_body["name"]
  end

  test "POST create com token write cria e devolve 201" do
    assert_difference -> { @user.clients.count }, +1 do
      post clients_path, headers: bearer(@write),
        params: { client: { name: "Novo", currency: "usd", rate_cents: 20000 } }, as: :json
    end
    assert_response :created
    body = response.parsed_body
    assert_equal "Novo", body["name"]
    assert_equal "USD", body["currency"]
    assert_equal 20000, body["rate_cents"]
  end

  test "POST create com token READ é rejeitado (401 — verbo×permission)" do
    assert_no_difference -> { @user.clients.count } do
      post clients_path, headers: bearer(@read),
        params: { client: { name: "Barrado" } }, as: :json
    end
    assert_response :unauthorized
  end

  test "POST create inválido devolve erros e 422" do
    post clients_path, headers: bearer(@write),
      params: { client: { name: "" } }, as: :json
    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
