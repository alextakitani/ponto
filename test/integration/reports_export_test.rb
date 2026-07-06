require "test_helper"
require "csv"

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

  def create_billable_project(name: "App do cliente", client_name: "Cliente Brasil", currency: "USD")
    client = @user.clients.create!(name: client_name, rate: 150, currency: currency)
    @user.projects.create!(name: name, client: client)
  end

  test "a tela de relatório mostra links de export que herdam o recorte da URL" do
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get reports_path(period: "custom", from: "2026-07-08", to: "2026-07-12")

    assert_response :success
    # link .xlsx preservando período/from/to
    assert_select "a[href*='/reports/export.xlsx'][href*='from=2026-07-08']"
    assert_select "a[href*='/reports/export.csv'][href*='to=2026-07-12']"
    # o seletor de idioma do export vive num turbo-frame; return_to (a tela atual,
    # com o recorte) viaja num hidden field, não na action.
    assert_select "turbo-frame#export_options" do
      assert_select "form[action*='/preferences']"
      assert_select "input[name=return_to][value*='from=2026-07-08']"
      assert_select "select[name='user[export_locale]']"
      assert_select "select[name='user[export_locale]'] option", text: "Português"
      assert_select "select[name='user[export_locale]'] option", text: "English"
    end
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

  test "export usa export_locale em inglês mantendo conteúdo e moeda do usuário intactos" do
    @user.update!(export_locale: "en")
    project = create_billable_project
    create_entry(
      started: Time.utc(2026, 7, 10, 12, 0),
      ended: Time.utc(2026, 7, 10, 13, 0),
      project: project,
      description: "Texto em português"
    )

    get export_reports_path(format: :csv)

    assert_response :success
    rows = CSV.parse(response.body)
    assert_includes rows.first, "Project"
    assert_includes rows.first, "Client"
    assert_includes rows.first, "Billable"
    assert_includes rows.first, "Rate/hour (USD)"
    assert_includes rows[1], "App do cliente"
    assert_includes rows[1], "Cliente Brasil"
    assert_includes rows[1], "Texto em português"
    assert_includes rows[1], "Yes"
    assert_includes rows[1], "150.0"
  end

  test "export usa export_locale em pt-BR com headers em português" do
    @user.update!(locale: "en", export_locale: "pt-BR")
    project = create_billable_project
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)

    get export_reports_path(format: :csv)

    assert_response :success
    headers = CSV.parse(response.body).first
    assert_includes headers, "Projeto"
    assert_includes headers, "Cliente"
    assert_includes headers, "Faturável"
    assert_includes headers, "Valor/hora (USD)"
  end

  test "export_locale válido no param vence a preferência salva" do
    @user.update!(export_locale: "pt-BR")
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv, export_locale: "en")

    assert_response :success
    assert_includes CSV.parse(response.body).first, "Project"
    assert_equal "pt-BR", @user.reload.export_locale
  end

  test "export_locale inválido no param cai silenciosamente para a preferência salva" do
    # pref = en, mas o idioma do request = pt-BR: um header em inglês SÓ prova que
    # caiu na PREFERÊNCIA (não no request-locale), isolando o degrau da precedência.
    @user.update!(locale: "pt-BR", export_locale: "en")
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv, export_locale: "de")

    assert_response :success
    assert_includes CSV.parse(response.body).first, "Project"
  end

  test "sem export_locale em param ou preferência usa o idioma atual do request" do
    @user.update!(locale: "en", export_locale: nil)
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv)

    assert_response :success
    assert_includes CSV.parse(response.body).first, "Project"
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

  test "filename do csv usa prefixo em inglês quando o export_locale é en" do
    @user.update!(export_locale: "en")
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv)

    assert_match(/filename="ponto-report-2026-07\.csv"/, response.headers["Content-Disposition"])
  end

  test "GET de download não altera User.export_locale" do
    @user.update!(export_locale: nil)
    create_entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    get export_reports_path(format: :csv, export_locale: "en")

    assert_response :success
    assert_nil @user.reload.export_locale
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

  # Trocar o idioma pelo seletor persiste e volta pro return_to; como o seletor
  # vive num turbo-frame, a resposta re-renderiza a tela (o Turbo extrai o frame) —
  # o popup de export não fecha. Aqui verificamos o lado servidor: persiste + volta.
  test "seletor de idioma do export persiste export_locale e volta pro return_to" do
    return_to = reports_path(period: "custom", from: "2026-07-08", to: "2026-07-12")

    patch preferences_path(return_to: return_to), params: { user: { export_locale: "en" } }

    assert_equal "en", @user.reload.export_locale
    assert_redirected_to return_to
  end
end
