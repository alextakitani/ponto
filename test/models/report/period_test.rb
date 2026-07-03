require "test_helper"

# Lógica NOSSA do Report::Period (Q53): presets, setas ‹ ›, e bordas do período
# calculadas SEMPRE no fuso do user (Q23b/Q6), não na constante global. Testamos o
# que é nosso: o intervalo resolvido e o passo das setas. Não testamos Date/Time do Ruby.
class Report::PeriodTest < ActiveSupport::TestCase
  test "este mês monta [1º dia 00:00, último dia 23:59:59] no fuso do user" do
    period = Report::Period.new(preset: "month", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    zone = ActiveSupport::TimeZone["America/Sao_Paulo"]
    assert_equal zone.local(2026, 7, 1, 0, 0, 0), period.range.begin
    assert_equal zone.local(2026, 7, 31).end_of_day, period.range.end
  end

  test "a borda do período muda com o fuso do user (não depende da constante global)" do
    sp = Report::Period.new(preset: "today", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")
    ny = Report::Period.new(preset: "today", today: Date.new(2026, 7, 15), time_zone: "America/New_York")

    # Meia-noite do mesmo dia em NY (UTC-4 no verão) é 1h DEPOIS da de SP (UTC-3).
    assert_operator ny.range.begin.utc, :>, sp.range.begin.utc
    assert_equal 1.hour.to_i, (ny.range.begin.utc - sp.range.begin.utc).to_i
  end

  test "seta ‹ › anda um mês pra trás/frente mantendo o preset month" do
    july = Report::Period.new(preset: "month", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    june = july.previous
    august = july.next

    assert_equal "month", june.preset
    assert_equal Date.new(2026, 6, 1), june.first_date
    assert_equal Date.new(2026, 6, 30), june.last_date
    assert_equal Date.new(2026, 8, 1), august.first_date
    assert_equal Date.new(2026, 8, 31), august.last_date
  end

  test "seta anda uma semana (segunda a domingo) pra trás/frente" do
    week = Report::Period.new(preset: "week", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2026, 7, 13), week.first_date  # segunda
    assert_equal Date.new(2026, 7, 19), week.last_date   # domingo
    assert_equal Date.new(2026, 7, 6), week.previous.first_date
    assert_equal Date.new(2026, 7, 20), week.next.first_date
  end

  test "custom anda pelo MESMO número de dias" do
    custom = Report::Period.new(preset: "custom", from: Date.new(2026, 7, 10), to: Date.new(2026, 7, 12), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2026, 7, 10), custom.first_date
    assert_equal Date.new(2026, 7, 12), custom.last_date
    # 3 dias de janela → recua 3 dias: 7..9
    assert_equal Date.new(2026, 7, 7), custom.previous.first_date
    assert_equal Date.new(2026, 7, 9), custom.previous.last_date
    assert_equal Date.new(2026, 7, 13), custom.next.first_date
    assert_equal Date.new(2026, 7, 15), custom.next.last_date
  end
end
