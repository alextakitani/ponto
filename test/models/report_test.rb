require "test_helper"

# Lógica NOSSA do Report (Q58) — o CORE do entregável principal. Testamos EXAUSTIVO:
# totais, agrupamento 1-2 níveis, baldes "(sem X)", corte de dia no fuso do user,
# subtotais por moeda com mix, rounding por entry, entry rodando FORA, isolamento.
# Cada teste cria só o que precisa (sem fixtures). O fuso default nos testes é
# America/Sao_Paulo (UTC-3), salvo quando o teste prova o corte de dia noutro fuso.
class ReportTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
  end

  # Helper: cria um entry finalizado com started/ended em UTC.
  def entry(started:, ended:, project: nil, task: nil, description: nil, billable: nil)
    attrs = { started_at: started, ended_at: ended }
    attrs[:project] = project if project
    attrs[:task] = task if task
    attrs[:description] = description if description
    attrs[:billable] = billable unless billable.nil? # false é significativo, NÃO removível
    @user.time_entries.create!(**attrs)
  end

  def month_period(today: Date.new(2026, 7, 15), tz: @user.time_zone)
    Report::Period.new(preset: "month", today: today, time_zone: tz)
  end

  test "totals soma a duração de todos os entries finalizados do período" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0)) # 1h
    entry(started: Time.utc(2026, 7, 11, 9, 0),  ended: Time.utc(2026, 7, 11, 11, 30)) # 2h30

    report = Report.new(user: @user, period: month_period)

    assert_equal 3.hours.to_i + 30.minutes.to_i, report.totals.duration_seconds
  end

  test "entry RODANDO fica FORA do relatório (Q57)" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0)) # 1h finalizado
    @user.time_entries.create!(started_at: Time.utc(2026, 7, 12, 10, 0)) # rodando (sem ended_at)

    report = Report.new(user: @user, period: month_period)

    assert_equal 1, report.rows.size
    assert_equal 1.hour.to_i, report.totals.duration_seconds
  end

  test "entry fora do período não entra" do
    entry(started: Time.utc(2026, 6, 30, 12, 0), ended: Time.utc(2026, 6, 30, 13, 0)) # junho
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0)) # julho

    report = Report.new(user: @user, period: month_period)

    assert_equal 1, report.rows.size
  end

  test "isolamento: entries de outro user nunca aparecem (Q23)" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))
    other = create_user(email: "alheio@example.com")
    other.time_entries.create!(started_at: Time.utc(2026, 7, 10, 14, 0), ended_at: Time.utc(2026, 7, 10, 15, 0))

    report = Report.new(user: @user, period: month_period)

    assert_equal 1, report.rows.size
    assert_equal 1.hour.to_i, report.totals.duration_seconds
  end

  test "corte do dia no fuso do user muda a data do balde (Q6)" do
    # 02/07 01:30 UTC = 01/07 22:30 em São Paulo (UTC-3) → cai no dia 01.
    e = entry(started: Time.utc(2026, 7, 2, 1, 30), ended: Time.utc(2026, 7, 2, 2, 30))

    sp_report = Report.new(user: @user, period: month_period)
    assert_equal Date.new(2026, 7, 1), sp_report.rows.first.date

    # Mesmo entry, user em UTC → cai no dia 02.
    @user.update!(time_zone: "UTC")
    utc_report = Report.new(user: @user, period: month_period(tz: "UTC"))
    assert_equal Date.new(2026, 7, 2), utc_report.rows.first.date
    assert_equal e.id, utc_report.rows.first.entry.id
  end

  test "daily_series tem uma barra por dia do período e materializa o corte de dia" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 14, 0)) # 2h no dia 10 SP

    report = Report.new(user: @user, period: month_period)

    assert_equal 31, report.daily_series.size # julho tem 31 dias
    dia10 = report.daily_series.find { |b| b.date == Date.new(2026, 7, 10) }
    assert_equal 2.hours.to_i, dia10.duration_seconds
    dia11 = report.daily_series.find { |b| b.date == Date.new(2026, 7, 11) }
    assert_equal 0, dia11.duration_seconds
  end

  test "amount usa o snapshot congelado (horas × rate) e billable_seconds só o faturável" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000) # R$100/h
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 14, 0), project: project) # 2h
    # não-faturável: mantém horas, zera amount
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: project, billable: false)

    report = Report.new(user: @user, period: month_period)

    assert_equal 3.hours.to_i, report.totals.duration_seconds
    assert_equal 2.hours.to_i, report.totals.billable_seconds # só o faturável
    assert_equal({ "BRL" => 20000 }, report.totals.amounts)   # 2h × 100 = 200,00
  end

  test "amount NÃO revaloriza quando a rate muda depois — usa o snapshot, não a rate atual (Q10)" do
    # A invariante de faturamento: mudar a rate do cliente/projeto NÃO reescreve o
    # histórico. Se o Report usasse project.effective_rate_cents (rate ATUAL) em vez
    # do snapshot congelado no entry, o total de um mês fechado mudaria — fatura errada.
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000) # R$100/h no lançamento
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 14, 0), project: project) # 2h → snapshot 100/h

    client.update!(rate_cents: 99999) # reajuste POSTERIOR

    report = Report.new(user: @user, period: month_period)
    assert_equal({ "BRL" => 20000 }, report.totals.amounts) # 2h × 100 (snapshot), NÃO × 999,99
  end

  test "mix de moedas vira SUBTOTAIS por moeda — NUNCA soma (Q43)" do
    brl = @user.clients.create!(name: "BR Co", currency: "BRL", rate_cents: 10000)
    eur = @user.clients.create!(name: "EU Co", currency: "EUR", rate_cents: 5000)
    brl_project = @user.projects.create!(name: "BR", client: brl)
    eur_project = @user.projects.create!(name: "EU", client: eur)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: brl_project) # 1h BRL
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: eur_project) # 1h EUR

    report = Report.new(user: @user, period: month_period)

    assert report.totals.multiple_currencies?
    assert_equal({ "BRL" => 10000, "EUR" => 5000 }, report.totals.amounts)
  end

  test "rounding por entry recalcula duração E amount, sem tocar o snapshot (Q56)" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 6000) # R$60/h
    project = @user.projects.create!(name: "Site", client: client)
    # 50 minutos reais → arredonda pra cima em bloco de 15 → 60 minutos.
    e = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 12, 50), project: project)

    rounding = Report::Rounding.new(block: 15, direction: "up")
    report = Report.new(user: @user, period: month_period, rounding: rounding)
    row = report.rows.first

    assert_equal 60.minutes.to_i, row.duration_seconds     # 50min → 60min
    assert_equal 6000, row.amount_cents                    # 1h × 60 = R$60,00
    assert_equal 60.minutes.to_i, report.totals.duration_seconds

    # snapshot intacto no banco (Q10/Q11): duração real ainda é 50min
    assert_equal 50.minutes.to_i, e.reload.duration_seconds
  end

  test "rounding OFF (default) usa a duração real" do
    e = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 12, 50))

    report = Report.new(user: @user, period: month_period)

    assert_equal 50.minutes.to_i, report.rows.first.duration_seconds
  end

  test "filtro por project_id (OR dentro da dimensão)" do
    a = @user.projects.create!(name: "A")
    b = @user.projects.create!(name: "B")
    c = @user.projects.create!(name: "C")
    ea = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)
    eb = entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: b)
    entry(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0), project: c)

    filters = Report::Filters.new(project_ids: [ a.id, b.id ])
    report = Report.new(user: @user, period: month_period, filters: filters)

    assert_equal [ ea.id, eb.id ].sort, report.rows.map { |r| r.entry.id }.sort
  end

  test "balde (sem projeto) filtrável junto com ids reais" do
    a = @user.projects.create!(name: "A")
    ea = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)
    solto = entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0)) # sem projeto

    # só o balde "(sem projeto)"
    none_only = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(project_ids: [ Report::Filters::NONE ]))
    assert_equal [ solto.id ], none_only.rows.map { |r| r.entry.id }

    # projeto A OU sem projeto
    both = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(project_ids: [ a.id, Report::Filters::NONE ]))
    assert_equal [ ea.id, solto.id ].sort, both.rows.map { |r| r.entry.id }.sort
  end

  test "filtro por client_id via join, incluindo o balde (sem cliente)" do
    client = @user.clients.create!(name: "Acme", currency: "BRL")
    with_client = @user.projects.create!(name: "P1", client: client)
    without_client = @user.projects.create!(name: "P2")
    ewc = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: with_client)
    ewoc = entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: without_client)
    solto = entry(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0))

    by_client = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(client_ids: [ client.id ]))
    assert_equal [ ewc.id ], by_client.rows.map { |r| r.entry.id }

    # "(sem cliente)" pega projeto sem client E entry sem projeto
    no_client = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(client_ids: [ Report::Filters::NONE ]))
    assert_equal [ ewoc.id, solto.id ].sort, no_client.rows.map { |r| r.entry.id }.sort
  end

  test "filtro billable (só faturável / só não)" do
    project = @user.projects.create!(name: "P", client: @user.clients.create!(name: "C", currency: "BRL", rate_cents: 5000))
    bill = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project, billable: true)
    nonbill = entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: project, billable: false)

    only_billable = Report.new(user: @user, period: month_period, filters: Report::Filters.new(billable: true))
    assert_equal [ bill.id ], only_billable.rows.map { |r| r.entry.id }

    only_non = Report.new(user: @user, period: month_period, filters: Report::Filters.new(billable: false))
    assert_equal [ nonbill.id ], only_non.rows.map { |r| r.entry.id }
  end

  test "filtro Description contains roda em Ruby, case-insensitive (Q54)" do
    match = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Refatorar o Backoffice")
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), description: "Deploy do site")

    report = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(description: "backoffice"))

    assert_equal [ match.id ], report.rows.map { |r| r.entry.id }
  end

  test "AND entre dimensões: project E billable" do
    a = @user.projects.create!(name: "A", client: @user.clients.create!(name: "C", currency: "BRL", rate_cents: 5000))
    b = @user.projects.create!(name: "B")
    hit = entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a, billable: true)
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: a, billable: false) # projeto ok, billable não
    entry(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0), project: b) # billable? sem rate → false

    report = Report.new(user: @user, period: month_period,
      filters: Report::Filters.new(project_ids: [ a.id ], billable: true))

    assert_equal [ hit.id ], report.rows.map { |r| r.entry.id }
  end

  test "group_by chega ao Grouping via Report (wiring)" do
    a = @user.projects.create!(name: "Alfa")
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0)) # sem projeto

    report = Report.new(user: @user, period: month_period, group_by: [ "project" ])

    assert_equal 2, report.groups.size
    assert_includes report.groups.map(&:title), "Alfa"
    assert_includes report.groups.map(&:title), "(sem projeto)"
  end
end
