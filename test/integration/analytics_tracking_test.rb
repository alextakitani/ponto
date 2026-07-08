require "test_helper"

# Tracking de analytics: a distinção NOSSA entre navegação de browser e acesso
# de máquina (CLI/extensão via Bearer). Regra (ver docs/adr/analytics-tracking.md):
#   - request web (GET HTML)      -> evento "$view", com visita (ahoy_visits)
#   - request de API (Bearer/JSON) -> evento "api_request", SEM visita órfã
# Assim o dashboard não mistura tráfego humano com uso de API, e a API não
# polui as métricas com visitas vazias.
class AnalyticsTrackingTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "analytics@example.com")
    @read = @user.access_tokens.create!(permission: "read")
  end

  test "acesso de API (Bearer/JSON) vira evento api_request, sem criar visita" do
    assert_difference -> { Ahoy::Event.where(name: "api_request").count }, +1 do
      assert_no_difference -> { Ahoy::Visit.count } do
        get tags_path, headers: bearer(@read), as: :json
      end
    end

    event = Ahoy::Event.where(name: "api_request").last
    assert_nil event.visit_id, "api_request não deve estar amarrado a uma visita"
    assert_equal @user.id, event.user_id, "deve carimbar o dono do token"
  end

  test "acesso de API NÃO gera evento $view" do
    assert_no_difference -> { Ahoy::Event.where(name: "$view").count } do
      get tags_path, headers: bearer(@read), as: :json
    end
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
