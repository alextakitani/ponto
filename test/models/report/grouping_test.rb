require "test_helper"

# Lógica NOSSA do Report::Grouping (Q21): agrupamento 1-2 níveis ANINHADOS por
# Project/Client/Task/Description, com baldes "(sem X)" e totais por grupo. Testamos
# a árvore resultante (títulos, contagem, durações, subtotais por moeda). Reusa
# Report::Row (a unidade que carrega duração/amount já resolvidos).
class Report::GroupingTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
    @zone = ActiveSupport::TimeZone["America/Sao_Paulo"]
  end

  # Constrói uma Row a partir de um entry criado no banco (rounding OFF).
  def row(started:, ended:, project: nil, task: nil, description: nil, billable: nil)
    attrs = { started_at: started, ended_at: ended }
    attrs[:project] = project if project
    attrs[:task] = task if task
    attrs[:description] = description if description
    attrs[:billable] = billable unless billable.nil?
    entry = @user.time_entries.create!(**attrs)
    Report::Row.new(entry, rounding: Report::Rounding.off, time_zone: @zone)
  end

  test "sem group_by devolve lista vazia (Summary cai só nos totais/barras)" do
    r = row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    grouping = Report::Grouping.new(rows: [ r ], group_by: nil)

    assert_empty grouping.groups
  end

  test "1 nível por projeto: título, contagem e duração por grupo + balde (sem projeto)" do
    a = @user.projects.create!(name: "Alfa")
    r1 = row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a) # 1h
    r2 = row(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 14, 0), project: a) # 2h
    r3 = row(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0))             # sem projeto 1h

    grouping = Report::Grouping.new(rows: [ r1, r2, r3 ], group_by: [ "project" ])
    groups = grouping.groups

    alfa = groups.find { |g| g.title == "Alfa" }
    assert_equal 2, alfa.count
    assert_equal 3.hours.to_i, alfa.duration_seconds

    sem = groups.find { |g| g.title == "(sem projeto)" }
    assert_equal 1, sem.count
    assert_equal 1.hour.to_i, sem.duration_seconds
  end

  test "grupo carrega subtotais por moeda (Q43) e tempo faturável" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000)
    project = @user.projects.create!(name: "Site", client: client)
    r1 = row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project) # 1h faturável
    r2 = row(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: project, billable: false)

    grouping = Report::Grouping.new(rows: [ r1, r2 ], group_by: [ "project" ])
    site = grouping.groups.first

    assert_equal 2.hours.to_i, site.duration_seconds
    assert_equal 1.hour.to_i, site.billable_seconds
    assert_equal({ "BRL" => 10000 }, site.amounts)
  end

  test "2 níveis aninhados: projeto → descrição, cada subgrupo soma e fecha no pai" do
    project = @user.projects.create!(name: "LaKube")
    r1 = row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project, description: "Astro")
    r2 = row(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 14, 0), project: project, description: "Astro")
    r3 = row(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0), project: project, description: "Backoffice")

    grouping = Report::Grouping.new(rows: [ r1, r2, r3 ], group_by: [ "project", "description" ])
    lakube = grouping.groups.first

    assert_equal 4.hours.to_i, lakube.duration_seconds
    assert_equal 2, lakube.subgroups.size

    astro = lakube.subgroups.find { |s| s.title == "Astro" }
    backoffice = lakube.subgroups.find { |s| s.title == "Backoffice" }
    assert_equal 3.hours.to_i, astro.duration_seconds
    assert_equal 2, astro.count
    assert_equal 1.hour.to_i, backoffice.duration_seconds
  end

  test "agrupar por task usa (sem tarefa) quando ausente" do
    project = @user.projects.create!(name: "P")
    task = @user.tasks.create!(name: "Deploy", project: project)
    r1 = row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project, task: task)
    r2 = row(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: project)

    grouping = Report::Grouping.new(rows: [ r1, r2 ], group_by: [ "task" ])
    titles = grouping.groups.map(&:title)

    assert_includes titles, "Deploy"
    assert_includes titles, "(sem tarefa)"
  end

  test "grupos ordenados por duração desc (maior primeiro)" do
    a = @user.projects.create!(name: "Pequeno")
    b = @user.projects.create!(name: "Grande")
    row(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)       # 1h
    row(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 15, 0), project: b)       # 3h

    grouping = Report::Grouping.new(rows: @user.time_entries.map { |e| Report::Row.new(e, rounding: Report::Rounding.off, time_zone: @zone) }, group_by: [ "project" ])

    assert_equal [ "Grande", "Pequeno" ], grouping.groups.map(&:title)
  end

  test "group_by tag duplica o mesmo entry em grupos diferentes e pode somar mais que o total" do
    first = @user.tags.create!(name: "Bug")
    second = @user.tags.create!(name: "Ops")
    entry = @user.time_entries.create!(started_at: Time.utc(2026, 7, 10, 12, 0), ended_at: Time.utc(2026, 7, 10, 13, 0))
    entry.tags << [ first, second ]
    row = Report::Row.new(entry, rounding: Report::Rounding.off, time_zone: @zone)

    grouping = Report::Grouping.new(rows: [ row ], group_by: [ "tag" ])

    assert_equal [ "Bug", "Ops" ], grouping.groups.map(&:title).sort
    assert_equal 2.hours.to_i, grouping.groups.sum(&:duration_seconds), "esperado: group-by tag conta o mesmo entry em N grupos"
  end
end
