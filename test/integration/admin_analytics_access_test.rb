require "test_helper"

# Auth do dashboard de analytics (AhoyCaptain montado em /admin/analytics).
# Engine MONTADA não passa pelo before_action do Admin::BaseController — a
# proteção é uma CONSTRAINT de rota que resolve a mesma sessão assinada do app
# (session_token) e só libera admin. Quando a constraint NÃO casa, a rota não
# existe pro roteador → o request cai fora do mount.
#
# Regra: analytics é dado OPERACIONAL do admin (exceção consciente ao Q23; ver
# docs/adr/analytics-tracking.md). Ninguém além do admin toca o dashboard.
class AdminAnalyticsAccessTest < ActionDispatch::IntegrationTest
  test "anônimo não acessa o dashboard de analytics" do
    get "/admin/analytics"
    # constraint nega (sem sessão) -> não entra no engine. Aceita redirect pro
    # login ou 404 (rota inexistente pra quem não é admin); o que NÃO pode é 200.
    assert_not_equal 200, response.status
  end

  test "user comum autenticado não acessa o dashboard de analytics" do
    sign_in_as("membro@example.com", keep_active_admin: true) # não-admin
    get "/admin/analytics"
    assert_not_equal 200, response.status
  end

  test "admin acessa o dashboard de analytics" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    get "/admin/analytics"
    assert_response :success
  end
end
