require "test_helper"

# Testa a agregação api_usage_by_endpoint (nossa lógica: json_extract + group +
# count/max no SQLite). Não testamos o tracking do Ahoy nem a serialização —
# isso é do framework.
class Ahoy::EventTest < ActiveSupport::TestCase
  def track_api_request(controller:, action:, method: "GET", format: "json", at: Time.current)
    Ahoy::Event.create!(
      name: Ahoy::Event::API_REQUEST,
      properties: { controller:, action:, method:, format: },
      time: at
    )
  end

  test "api_usage_by_endpoint agrupa por controller#action e método, contando e pegando o último acesso" do
    older = Time.utc(2026, 1, 1, 10, 0, 0)
    newer = Time.utc(2026, 1, 2, 15, 30, 0)
    track_api_request(controller: "timers", action: "show", at: older)
    track_api_request(controller: "timers", action: "show", at: newer)
    track_api_request(controller: "time_entries", action: "index")

    rows = Ahoy::Event.api_usage_by_endpoint

    timers = rows.find { |r| r.endpoint == "timers#show" }
    assert_equal 2, timers.count
    assert_equal "GET", timers.method
    assert_equal newer, timers.last_time

    assert_includes rows.map(&:endpoint), "time_entries#index"
  end

  test "api_usage_by_endpoint ordena do endpoint mais chamado pro menos" do
    3.times { track_api_request(controller: "timers", action: "show") }
    1.times { track_api_request(controller: "tags", action: "index") }

    rows = Ahoy::Event.api_usage_by_endpoint

    assert_equal "timers#show", rows.first.endpoint
    assert_operator rows.first.count, :>, rows.last.count
  end

  test "api_usage_by_endpoint ignora eventos que não são api_request" do
    track_api_request(controller: "timers", action: "show")
    Ahoy::Event.create!(name: "$view", properties: { controller: "home", action: "show" }, time: Time.current)

    rows = Ahoy::Event.api_usage_by_endpoint

    assert_equal 1, rows.size
    assert_equal "timers#show", rows.first.endpoint
  end
end
