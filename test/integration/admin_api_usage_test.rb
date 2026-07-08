require "test_helper"

# Página de Uso da API (/admin/api_usage). Mesma autorização do namespace admin
# (Q40/Q41): não-admin barrado; admin acessa. A página lê Ahoy::Event.api_request
# direto (o AhoyCaptain não os mostra — não têm visita). Ver ADR analytics.
class AdminApiUsageTest < ActionDispatch::IntegrationTest
  test "user comum autenticado recebe 403" do
    sign_in_as("membro@example.com", keep_active_admin: true) # não-admin
    get admin_api_usage_path
    assert_response :forbidden
  end

  test "admin vê os acessos de API agrupados por endpoint" do
    Ahoy::Event.create!(
      name: Ahoy::Event::API_REQUEST,
      properties: { controller: "timers", action: "show", method: "GET", format: "json" },
      time: Time.current
    )

    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    get admin_api_usage_path

    assert_response :success
    assert_select "code", text: "timers#show"
  end

  test "admin vê estado vazio quando não há acesso de API" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    get admin_api_usage_path

    assert_response :success
  end
end
