require "test_helper"

# Lógica NOSSA do Report::Rounding (Q56): arredonda a DURAÇÃO por entry em blocos de
# 5/15/30 min, nas direções cima/próximo/baixo. É só leitura — nunca toca o snapshot.
# Testamos a matemática do arredondamento; o efeito no amount é testado no ReportTest.
class Report::RoundingTest < ActiveSupport::TestCase
  test "off devolve a duração intacta" do
    rounding = Report::Rounding.off

    assert_not rounding.on?
    assert_equal 3661, rounding.round_seconds(3661) # 1h01m01s intocado
  end

  test "próximo arredonda pro bloco mais perto (default 15 min)" do
    rounding = Report::Rounding.new(block: 15, direction: "nearest")

    assert_equal 0,            rounding.round_seconds(0)
    assert_equal 15 * 60,      rounding.round_seconds(8 * 60)   # 8min → 15min (mais perto)
    assert_equal 0,            rounding.round_seconds(7 * 60)   # 7min → 0 (mais perto)
    assert_equal 15 * 60,      rounding.round_seconds(15 * 60)  # exato fica
  end

  test "cima sempre sobe pro próximo bloco; baixo sempre desce" do
    up   = Report::Rounding.new(block: 15, direction: "up")
    down = Report::Rounding.new(block: 15, direction: "down")

    assert_equal 15 * 60, up.round_seconds(1 * 60)    # 1min → 15min
    assert_equal 15 * 60, up.round_seconds(15 * 60)   # exato não sobe
    assert_equal 30 * 60, up.round_seconds(16 * 60)   # 16min → 30min

    assert_equal 0,       down.round_seconds(14 * 60) # 14min → 0
    assert_equal 15 * 60, down.round_seconds(29 * 60) # 29min → 15min
  end

  test "blocos de 5 e 30 minutos" do
    five  = Report::Rounding.new(block: 5, direction: "nearest")
    half  = Report::Rounding.new(block: 30, direction: "up")

    assert_equal 5 * 60,  five.round_seconds(3 * 60)  # 3min → 5min
    assert_equal 30 * 60, half.round_seconds(1 * 60)  # 1min → 30min
  end

  test "bloco inválido cai no default 15 e direção inválida em nearest" do
    rounding = Report::Rounding.new(block: 99, direction: "sideways")

    assert_equal 15 * 60, rounding.round_seconds(8 * 60)
  end
end
