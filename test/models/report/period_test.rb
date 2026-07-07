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

  test "mês passado monta a janela do mês anterior completo" do
    period = Report::Period.new(preset: "last_month", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2026, 6, 1), period.first_date
    assert_equal Date.new(2026, 6, 30), period.last_date
  end

  test "mês passado atravessa a virada de ano (janeiro → dezembro anterior)" do
    period = Report::Period.new(preset: "last_month", today: Date.new(2026, 1, 10), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2025, 12, 1), period.first_date
    assert_equal Date.new(2025, 12, 31), period.last_date
  end

  test "ano passado monta a janela do ano anterior completo" do
    period = Report::Period.new(preset: "last_year", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2025, 1, 1), period.first_date
    assert_equal Date.new(2025, 12, 31), period.last_date
  end

  # A sutileza: navegar a partir de "mês passado" re-ancora como "mês" — a › a partir
  # de maio mostra junho rotulado como mês normal, não "mês passado" mentindo.
  test "seta a partir de mês passado vira o preset month re-ancorado" do
    period = Report::Period.new(preset: "last_month", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    forward = period.next  # junho → julho
    assert_equal "month", forward.preset
    assert_equal Date.new(2026, 7, 1), forward.first_date
    assert_equal Date.new(2026, 7, 31), forward.last_date

    back = period.previous # junho → maio
    assert_equal "month", back.preset
    assert_equal Date.new(2026, 5, 1), back.first_date
  end

  test "seta a partir de ano passado vira o preset year re-ancorado" do
    period = Report::Period.new(preset: "last_year", today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    assert_equal "year", period.next.preset
    assert_equal Date.new(2026, 1, 1), period.next.first_date
    assert_equal Date.new(2024, 1, 1), period.previous.first_date
  end

  # Bug 07/07: as setas viravam nav= relativo sobre o período-base do preset — next
  # mostrava agosto mas o prev seguinte caía em junho (pulava julho). O conserto:
  # preset nomeado aceita `from` como ÂNCORA absoluta (o que as setas põem na URL).
  test "preset nomeado ancora em from quando presente (URL absoluta das setas)" do
    period = Report::Period.new(preset: "month", from: Date.new(2026, 8, 1), today: Date.new(2026, 7, 15), time_zone: "America/Sao_Paulo")

    assert_equal Date.new(2026, 8, 1), period.first_date
    assert_equal Date.new(2026, 8, 31), period.last_date
  end

  test "ida e volta das setas devolve o período original em todos os presets" do
    today = Date.new(2026, 7, 15)

    %w[today week month year].each do |preset|
      period = Report::Period.new(preset: preset, today: today, time_zone: "America/Sao_Paulo")

      # Simula o fluxo REAL da UI: cada clique reconstrói o Period a partir da URL
      # absoluta (preset + from) que a seta anterior gerou.
      forward = Report::Period.new(preset: period.next.preset, from: period.next.first_date, today: today, time_zone: "America/Sao_Paulo")
      back = Report::Period.new(preset: forward.previous.preset, from: forward.previous.first_date, today: today, time_zone: "America/Sao_Paulo")

      assert_equal period.first_date, back.first_date, "preset #{preset}: ida e volta mudou o início"
      assert_equal period.last_date, back.last_date, "preset #{preset}: ida e volta mudou o fim"
    end
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
