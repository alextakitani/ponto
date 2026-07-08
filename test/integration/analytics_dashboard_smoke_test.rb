require "test_helper"
# Smoke: exercita TODAS as páginas GET do dashboard AhoyCaptain de uma vez, pra
# pegar qualquer SQL Postgres que meu port não traduziu (cada página = query
# diferente). Autorização: só admin (gate no initializer, não constraint).
class AnalyticsDashboardSmokeTest < ActionDispatch::IntegrationTest
  # coletadas de `bin/rails routes` (engine montada em /admin/analytics)
  PATHS = %w[
    /admin/analytics
    /admin/analytics/stats
    /admin/analytics/top_pages
    /admin/analytics/sources
    /admin/analytics/entry_pages
    /admin/analytics/exit_pages
    /admin/analytics/campaigns/utm_source
    /admin/analytics/campaigns/utm_medium
    /admin/analytics/campaigns/utm_campaign
    /admin/analytics/devices/browsers
    /admin/analytics/devices/operating_systems
    /admin/analytics/devices/device_types
    /admin/analytics/locations/countries
    /admin/analytics/locations/regions
    /admin/analytics/locations/cities
    /admin/analytics/properties
  ]

  test "admin acessa todas as páginas do dashboard sem 500" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    failures = []
    PATHS.each do |path|
      get path
      failures << "#{path} -> #{response.status}" if response.status >= 500
    rescue => e
      failures << "#{path} -> RAISED #{e.class}: #{e.message[0, 80]}"
    end
    assert failures.empty?, "Páginas com erro:\n#{failures.join("\n")}"
  end
end
