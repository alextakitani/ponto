require "test_helper"

# Portabilidade JSON — EXPORT (Q26/Q72), fluxo HTTP. Verifica o download autenticado,
# o gate de login, o isolamento por user (Q23) e o Bearer (CLI/extensão).
class Account::DataExportTest < ActionDispatch::IntegrationTest
  test "GET autenticado baixa o JSON como anexo" do
    user = create_user(email: "exporter@example.com")
    user.clients.create!(name: "Acme", rate_cents: 10000, currency: "BRL")
    sign_in_as("exporter@example.com", user: user)

    get account_data_export_path(format: :json)

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/ponto-export-.*\.json/, response.headers["Content-Disposition"])

    document = JSON.parse(response.body)
    assert_equal 1, document["schema_version"]
    assert_equal "Acme", document["clients"].first["name"]
  end

  test "sem login redireciona pro sign in" do
    get account_data_export_path(format: :json)

    assert_response :unauthorized
  end

  test "Bearer read baixa o export" do
    user = create_user(email: "bearer-export@example.com")
    token = user.access_tokens.create!(permission: "read")
    user.clients.create!(name: "Acme")

    get account_data_export_path(format: :json), headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_equal "Acme", JSON.parse(response.body)["clients"].first["name"]
  end

  test "isolamento Q23: o export traz só a bolha do requester" do
    owner = create_user(email: "owner-export@example.com")
    other = create_user(email: "other-export@example.com")
    owner.clients.create!(name: "Mine")
    other.clients.create!(name: "Theirs")
    sign_in_as("owner-export@example.com", user: owner)

    get account_data_export_path(format: :json)

    document = JSON.parse(response.body)
    assert_equal [ "Mine" ], document["clients"].map { |client| client["name"] }
  end

  test "conta suspensa ainda consegue exportar (rota isenta do gate)" do
    other_admin = create_user(email: "keep-admin@example.com", admin: true)
    user = create_user(email: "suspended-export@example.com")
    user.clients.create!(name: "Acme")
    sign_in_as("suspended-export@example.com", user: user)
    user.update!(suspended_at: Time.current)

    get account_data_export_path(format: :json)

    assert_response :success
    assert_equal "Acme", JSON.parse(response.body)["clients"].first["name"]
  end
end
