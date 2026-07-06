require "test_helper"

# Testa SÓ a lógica NOSSA do rótulo de dia (não o strftime do framework): o corte
# "Hoje"/"Ontem" é relativo ao FUSO DO USER (Q6/Q23b), e datas antigas ganham o dia
# da semana em pt-BR (o app não carrega rails-i18n, então formatamos à mão — sem
# I18n.l, que levantaria MissingTranslationData).
class TrackerHelperTest < ActionView::TestCase
  test "hoje/ontem são relativos ao fuso do user, não ao do servidor" do
    # 03/07 00:30 UTC ainda é 02/07 (21:30) em São Paulo (UTC-3). O corte tem que
    # seguir o fuso do user: nesse instante, "hoje" pro user é 02/07.
    user = create_user
    user.update!(time_zone: "America/Sao_Paulo")
    Current.user = user

    travel_to Time.utc(2026, 7, 3, 0, 30) do
      assert_equal "Hoje", tracker_day_label(Date.new(2026, 7, 2))
      assert_equal "Ontem", tracker_day_label(Date.new(2026, 7, 1))
      # O dia UTC (03/07) ainda NÃO chegou pro user → não é "Hoje".
      assert_not_equal "Hoje", tracker_day_label(Date.new(2026, 7, 3))
    end
  end

  test "data antiga leva o dia da semana abreviado em pt-BR" do
    user = create_user
    user.update!(time_zone: "America/Sao_Paulo")
    Current.user = user

    travel_to Time.utc(2026, 7, 3, 12, 0) do
      # 30/06/2026 é uma terça-feira.
      assert_equal "ter, 30/06/2026", tracker_day_label(Date.new(2026, 6, 30))
    end
  end

  # Total de valores do dia (Q43): soma por moeda, NUNCA mistura; vazio → nil (o
  # cabeçalho não mostra "—" quando não há faturável).
  test "tracker_day_amounts soma cents por moeda e formata" do
    assert_nil tracker_day_amounts({})
    assert_nil tracker_day_amounts(nil)

    single = tracker_day_amounts({ "EUR" => 13_318 })
    assert_includes single, "133,18"

    # Duas moedas: subtotais separados, unidos pelo middle-dot — nunca somados.
    multi = tracker_day_amounts({ "EUR" => 13_318, "BRL" => 5_000 })
    assert_includes multi, "133,18"
    assert_includes multi, "50,00"
  end

  test "tracker_overlapping_entry_ids marca par sobreposto" do
    first = tracker_entry(1, "2026-07-02 09:00", "2026-07-02 10:00")
    second = tracker_entry(2, "2026-07-02 09:30", "2026-07-02 10:30")
    third = tracker_entry(3, "2026-07-02 11:00", "2026-07-02 12:00")

    assert_equal Set[1, 2], tracker_overlapping_entry_ids([ first, second, third ])
  end

  test "tracker_overlapping_entry_ids devolve vazio sem sobreposição" do
    first = tracker_entry(1, "2026-07-02 09:00", "2026-07-02 10:00")
    second = tracker_entry(2, "2026-07-02 10:30", "2026-07-02 11:30")

    assert_empty tracker_overlapping_entry_ids([ first, second ])
  end

  test "tracker_overlapping_entry_ids ignora toque na borda" do
    first = tracker_entry(1, "2026-07-02 09:00", "2026-07-02 10:00")
    second = tracker_entry(2, "2026-07-02 10:00", "2026-07-02 11:00")

    assert_empty tracker_overlapping_entry_ids([ first, second ])
  end

  private
    TrackerEntry = Struct.new(:id, :started_at, :ended_at)

    def tracker_entry(id, started_at, ended_at)
      TrackerEntry.new(id, Time.zone.parse(started_at), Time.zone.parse(ended_at))
    end
end
