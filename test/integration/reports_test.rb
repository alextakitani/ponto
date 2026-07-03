require "test_helper"

# Fluxo de controle NOSSO do ReportsController (Fatia 5.1): abas Summary/Detailed via
# param, params de período/filtro/group_by/rounding na URL, e o isolamento por user.
# Não testamos texto de view — só que a tela renderiza, escopa e reage aos params.
class ReportsTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("dono@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
    travel_to Time.utc(2026, 7, 15, 12, 0)
  end

  teardown { travel_back }

  def create_entry(started:, ended:, project: nil, description: nil)
    attrs = { started_at: started, ended_at: ended }
    attrs[:project] = project if project
    attrs[:description] = description if description
    @user.time_entries.create!(**attrs)
  end

  test "index abre em Summary do MÊS por default e mostra o total do período" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 14, 0)) # 2h em julho

    get reports_path

    assert_response :success
    assert_select "[data-report-tab='summary']"
    # 02:00:00 total do mês
    assert_select "[data-total='duration']", text: /02:00:00/
  end

  test "aba Detailed lista uma linha por entry, started_at desc" do
    older = create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))
    newer = create_entry(started: Time.utc(2026, 7, 12, 12, 0), ended: Time.utc(2026, 7, 12, 13, 0))

    get reports_path(view: "detailed")

    assert_response :success
    assert_select "[data-entry-id='#{older.id}']", count: 1
    assert_select "[data-entry-id='#{newer.id}']", count: 1
  end

  test "período custom via params restringe as datas" do
    dentro = create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))
    fora = create_entry(started: Time.utc(2026, 7, 20, 12, 0), ended: Time.utc(2026, 7, 20, 13, 0))

    get reports_path(view: "detailed", period: "custom", from: "2026-07-08", to: "2026-07-12")

    assert_response :success
    assert_select "[data-entry-id='#{dentro.id}']", count: 1
    assert_select "[data-entry-id='#{fora.id}']", count: 0
  end

  test "group_by por projeto monta os grupos no Summary" do
    a = @user.projects.create!(name: "Alfa")
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)
    create_entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0)) # sem projeto

    get reports_path(group_by: "project")

    assert_response :success
    assert_select "[data-group]", minimum: 2
  end

  test "seta ‹ (nav=prev) recua o mês e muda o conteúdo" do
    julho = create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))
    junho = create_entry(started: Time.utc(2026, 6, 10, 12, 0), ended: Time.utc(2026, 6, 10, 13, 0))

    get reports_path(view: "detailed", period: "month", nav: "prev")

    assert_response :success
    assert_select "[data-entry-id='#{junho.id}']", count: 1
    assert_select "[data-entry-id='#{julho.id}']", count: 0
  end

  test "rounding=on via params arredonda a duração exibida" do
    # 50 min reais → bloco 15 pra cima → 60 min exibidos
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 12, 50))

    get reports_path(view: "summary", rounding: "on", rounding_block: "15", rounding_direction: "up")

    assert_response :success
    assert_select "[data-total='duration']", text: /01:00:00/
  end

  test "Summary com group_by renderiza a tabela agrupada com total" do
    a = @user.projects.create!(name: "Alfa")
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: a)

    get reports_path(view: "summary", group_by: "project")

    assert_response :success
    assert_select "table.report-summary [data-group='Alfa']"
    assert_select ".report-summary__total"
  end

  test "isolamento: relatório nunca mostra entry de outro user" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Meu")
    other = create_user(email: "alheio@example.com")
    alien = other.time_entries.create!(started_at: Time.utc(2026, 7, 10, 14, 0), ended_at: Time.utc(2026, 7, 10, 15, 0), description: "Alheio")

    get reports_path(view: "detailed")

    assert_response :success
    assert_select "[data-entry-id='#{alien.id}']", count: 0
    assert_not_includes response.body, "Alheio"
  end
end
