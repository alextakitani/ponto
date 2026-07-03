require "test_helper"

# Fluxo de controle NOSSO do export (Fatia 5.2): GET /reports/export.{xlsx,csv} responde
# send_data com o content-type certo, o período no filename, e HERDA o mesmo recorte
# (período/filtros) da URL do relatório. Isolamento (Q23): export de A nunca vaza B.
# Não afERimos bytes do xlsx aqui (isso é do ExportTest) — só o fluxo do controller.
class ReportsExportTest < ActionDispatch::IntegrationTest
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

  test "a tela de relatório mostra links de export que herdam o recorte da URL" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get reports_path(period: "custom", from: "2026-07-08", to: "2026-07-12")

    assert_response :success
    # link .xlsx preservando período/from/to
    assert_select "a[href*='/reports/export.xlsx'][href*='from=2026-07-08']"
    assert_select "a[href*='/reports/export.csv'][href*='to=2026-07-12']"
  end

  test "GET /reports/export.xlsx responde send_data com content-type xlsx e período no filename" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :xlsx)

    assert_response :success
    assert_equal(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      response.media_type
    )
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_match(/2026-07/, response.headers["Content-Disposition"]) # período no nome
    assert response.body.bytesize.positive?
  end

  test "GET /reports/export.csv responde send_data com content-type csv e o header" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Trabalho")

    get export_reports_path(format: :csv)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_includes response.body, "Projeto" # header da matriz
    assert_includes response.body, "Trabalho"
  end

  test "export HERDA o período custom da URL (mesmo recorte que a tela)" do
    dentro = create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Dentro")
    create_entry(started: Time.utc(2026, 7, 20, 12, 0), ended: Time.utc(2026, 7, 20, 13, 0), description: "Fora")

    get export_reports_path(format: :csv, period: "custom", from: "2026-07-08", to: "2026-07-12")

    assert_response :success
    assert_includes response.body, "Dentro"
    assert_not_includes response.body, "Fora"
  end

  test "filename do csv carrega o período (ex.: ponto-relatorio-2026-07.csv)" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv)

    assert_match(/filename="ponto-relatorio-2026-07\.csv"/, response.headers["Content-Disposition"])
  end

  test "isolamento: export nunca traz entry de outro user" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Meu")
    other = create_user(email: "alheio@example.com")
    other.time_entries.create!(
      started_at: Time.utc(2026, 7, 10, 14, 0), ended_at: Time.utc(2026, 7, 10, 15, 0), description: "Alheio"
    )

    get export_reports_path(format: :csv)

    assert_response :success
    assert_not_includes response.body, "Alheio"
  end

  test "export exige login: sem sessão o CSV é NEGADO (não vaza dado)" do
    reset!  # limpa a sessão (novo integration session sem cookies)

    get export_reports_path(format: :csv)

    # require_authentication só responde html (redirect) / json (401); um formato de
    # export sem sessão cai em 406 — o que importa é que NÃO é 2xx e não serve dados.
    assert_not response.successful?
    assert_response :not_acceptable
  end

  test "export exige login: a versão HTML (sem sessão) redireciona pro sign in" do
    reset!

    get export_reports_path # sem extensão → html

    assert_redirected_to sign_in_path
  end
end
