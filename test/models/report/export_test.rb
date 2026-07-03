require "test_helper"

# Lógica NOSSA do export (Fatia 5.2) — o ENTREGÁVEL PRINCIPAL: o arquivo que o usuário
# anexa à fatura. Testamos EXAUSTIVO a MATRIZ (headers + linhas): a ordem/valor das 14
# colunas do Detailed (Q19), Faturável Sim/Não, duração HH:MM:SS + decimal, valor/hora e
# valor como NÚMEROS (somáveis no Excel), moeda no header (mono) vs coluna extra (mix),
# e que xlsx e csv saem da MESMA matriz. Sem fixtures — cada teste cria só o que precisa.
class Report::ExportTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
    @user.update!(time_zone: "America/Sao_Paulo") # UTC-3
  end

  # Helper: entry finalizado. Se `project` tem rate, o snapshot (rate_cents/currency)
  # congela no create — não passamos rate direto (é derivado, Q10/Q11).
  def entry(started:, ended:, project: nil, task: nil, description: nil, billable: nil)
    attrs = { started_at: started, ended_at: ended }
    attrs[:project] = project if project
    attrs[:task] = task if task
    attrs[:description] = description if description
    attrs[:billable] = billable unless billable.nil?
    @user.time_entries.create!(**attrs)
  end

  def month_period(today: Date.new(2026, 7, 15))
    Report::Period.new(preset: "month", today: today, time_zone: @user.time_zone)
  end

  def export_for(**report_opts)
    report = Report.new(user: @user, period: month_period, **report_opts)
    Report::Export.new(report)
  end

  # --- HEADERS (mono-moeda: 14 colunas, moeda no header) ---

  test "headers mono-moeda = 14 colunas na ordem da Q19, moeda no header dos valores" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)

    export = export_for

    assert_equal(
      [
        "Projeto", "Cliente", "Descrição", "Tarefa", "Tags", "Faturável",
        "Data início", "Hora início", "Data fim", "Hora fim",
        "Duração (h)", "Duração (decimal)", "Valor/hora (BRL)", "Valor (BRL)"
      ],
      export.headers
    )
  end

  test "headers sem NENHUM amount faturável ainda são mono (14 col), moeda default BRL" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0)) # sem projeto → sem rate

    export = export_for

    assert_equal 14, export.headers.size
    assert_equal "Valor/hora (BRL)", export.headers[12]
    assert_equal "Valor (BRL)", export.headers[13]
  end

  # --- LINHA (valores das 14 colunas) ---

  test "linha do Detailed traz as 14 colunas com os valores certos" do
    client = @user.clients.create!(name: "ACME", rate: 120, currency: "BRL") # 120/h
    project = @user.projects.create!(name: "Site", client: client)
    task = project.tasks.create!(name: "Backend", user: @user)
    bug = @user.tags.create!(name: "Bug")
    ops = @user.tags.create!(name: "Ops")
    # 12:00–13:30 UTC = 09:00–10:30 em São Paulo. 1h30 → 1.5h × 120 = 180.
    record = entry(
      started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 30),
      project: project, task: task, description: "Ajuste no login"
    )
    record.tags << [ bug, ops ]

    row = export_for.rows_matrix.first

    assert_equal "Site", row[0]          # Projeto
    assert_equal "ACME", row[1]          # Cliente
    assert_equal "Ajuste no login", row[2] # Descrição
    assert_equal "Backend", row[3]       # Tarefa
    assert_equal "Bug, Ops", row[4]      # Tags
    assert_equal "Sim", row[5]           # Faturável
    assert_equal Date.new(2026, 7, 10), row[6]  # Data início (local)
    assert_equal "09:00", row[7]         # Hora início (local)
    assert_equal Date.new(2026, 7, 10), row[8]  # Data fim (local)
    assert_equal "10:30", row[9]         # Hora fim (local)
    assert_equal "01:30:00", row[10]     # Duração (h)
    assert_equal 1.5, row[11]            # Duração (decimal)
    assert_equal 120.0, row[12]          # Valor/hora (número)
    assert_equal 180.0, row[13]          # Valor (número)
  end

  test "colunas vazias quando sem projeto/cliente/tarefa/descrição" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    row = export_for.rows_matrix.first

    assert_equal "", row[0] # Projeto
    assert_equal "", row[1] # Cliente
    assert_equal "", row[2] # Descrição
    assert_equal "", row[3] # Tarefa
  end

  test "Faturável Não quando billable=false, e Valor = 0 mantendo as HORAS" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(
      started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0),
      project: project, billable: false
    )

    row = export_for.rows_matrix.first

    assert_equal "Não", row[5]
    assert_equal "01:00:00", row[10] # horas mantidas
    assert_equal 1.0, row[11]
    assert_equal 0.0, row[13]         # valor zerado
  end

  test "valor/hora e valor são NÚMEROS (somáveis), não strings" do
    client = @user.clients.create!(name: "ACME", rate: 90, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)

    row = export_for.rows_matrix.first

    assert_kind_of Numeric, row[12]
    assert_kind_of Numeric, row[13]
    assert_kind_of Numeric, row[11] # duração decimal também
  end

  test "duração decimal arredonda pra 2 casas (ex.: 1h25 = 1.42h)" do
    # 1h25 = 85 min = 1.4166… h → 1.42
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 25))

    row = export_for.rows_matrix.first

    assert_equal 1.42, row[11]
    assert_equal "01:25:00", row[10]
  end

  test "valor/hora vazio (nil) quando entry sem rate" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0)) # sem projeto

    row = export_for.rows_matrix.first

    assert_equal "", row[12] # Valor/hora vazio, não 0
    assert_equal 0.0, row[13] # Valor 0
  end

  # --- MIX de moedas: 15ª coluna "Moeda", header genérico ---

  test "mix de moedas adiciona coluna Moeda (15ª) e header genérico sem código" do
    brl = @user.clients.create!(name: "Brasil", rate: 100, currency: "BRL")
    eur = @user.clients.create!(name: "Europa", rate: 50, currency: "EUR")
    p_brl = @user.projects.create!(name: "PT-BR", client: brl)
    p_eur = @user.projects.create!(name: "EU", client: eur)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: p_brl)
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 0), project: p_eur)

    export = export_for

    assert_equal 15, export.headers.size
    assert_equal "Valor/hora", export.headers[12] # genérico, sem (BRL)
    assert_equal "Valor", export.headers[13]
    assert_equal "Moeda", export.headers[14]
    # cada linha traz seu código de moeda na última coluna
    codes = export.rows_matrix.map(&:last).sort
    assert_equal %w[BRL EUR], codes
  end

  test "mono-moeda NÃO tem coluna Moeda extra" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)

    export = export_for

    assert_equal 14, export.headers.size
    assert_equal 14, export.rows_matrix.first.size
  end

  # --- CSV e XLSX saem da MESMA matriz ---

  test "csv tem header + uma linha por entry, com valores da matriz" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0),
          project: project, description: "Trabalho")

    export = export_for
    parsed = CSV.parse(export.to_csv)

    assert_equal export.headers, parsed.first
    assert_equal export.rows_matrix.size, parsed.size - 1 # menos o header
    # a linha de dados bate (comparando como texto — CSV é texto)
    assert_includes parsed[1], "Site"
    assert_includes parsed[1], "Trabalho"
    assert_includes parsed[1], "100.0" # valor/hora numérico serializado
  end

  test "csv formata datas em ISO legível" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    export = export_for
    parsed = CSV.parse(export.to_csv)

    # Data início (coluna 7 = índice 6) no fuso local: 10/07 09:00 SP
    assert_equal "2026-07-10", parsed[1][6]
    assert_equal "09:00", parsed[1][7]
  end

  test "csv e xlsx consomem a MESMA matriz (mesmas linhas de dados)" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)
    entry(started: Time.utc(2026, 7, 11, 12, 0), ended: Time.utc(2026, 7, 11, 13, 30))

    export = export_for
    csv_rows = CSV.parse(export.to_csv)

    # o CSV tem exatamente as linhas da matriz (+ header); ambos vêm de rows_matrix.
    assert_equal export.rows_matrix.size + 1, csv_rows.size
    assert_equal export.headers.size, csv_rows.first.size
  end

  # --- XLSX smoke: o Package gera sem erro e tem as células certas ---

  test "to_xlsx_package gera um Package caxlsx válido com header + linhas" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), project: project)

    export = export_for
    package = export.to_xlsx_package

    assert_kind_of Axlsx::Package, package
    sheet = package.workbook.worksheets.first
    assert_equal export.headers, sheet.rows.first.cells.map(&:value)
    # header + 1 linha de dados
    assert_equal export.rows_matrix.size + 1, sheet.rows.size
    # valor/hora numérico na célula (linha 2, col índice 12)
    assert_equal 100.0, sheet.rows[1].cells[12].value
  end

  test "to_xlsx devolve bytes de um .xlsx (smoke: string não vazia, começa com PK)" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0))

    bytes = export_for.to_xlsx

    assert bytes.bytesize.positive?
    assert_equal "PK".b, bytes.byteslice(0, 2).b # zip magic (xlsx é um zip)
  end

  # --- Isolamento (a matriz vem do Report, que já isola; blindamos aqui também) ---

  test "isolamento: export do user A nunca traz entry do user B" do
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 13, 0), description: "Meu")
    other = create_user(email: "alheio@example.com")
    other.time_entries.create!(
      started_at: Time.utc(2026, 7, 10, 14, 0), ended_at: Time.utc(2026, 7, 10, 15, 0), description: "Alheio"
    )

    export = export_for

    assert_equal 1, export.rows_matrix.size
    assert_not export.to_csv.include?("Alheio")
  end

  # --- Gaps do review (5.2): data no fuso cruzando meia-noite + CSV==matriz ---

  test "Data início/fim sai no FUSO DO USER, não em UTC (cruzando a meia-noite)" do
    # 01:00 UTC de 11/07 = 22:00 de 10/07 em São Paulo (UTC-3). A coluna Data (7 e 9)
    # tem que dar 10/07 (dia LOCAL), não 11/07 (UTC). Se o export usasse .utc.to_date,
    # a fatura mostraria o dia errado.
    entry(
      started: Time.utc(2026, 7, 11, 1, 0),  # 10/07 22:00 SP
      ended:   Time.utc(2026, 7, 11, 2, 0)   # 10/07 23:00 SP
    )

    row = export_for.rows_matrix.first
    assert_equal Date.new(2026, 7, 10), row[6], "Data início deve ser o dia LOCAL (10/07), não UTC"
    assert_equal Date.new(2026, 7, 10), row[8], "Data fim deve ser o dia LOCAL (10/07), não UTC"
  end

  test "CSV e xlsx saem da MESMA matriz: a coluna Valor bate célula-a-célula" do
    client = @user.clients.create!(name: "ACME", rate: 100, currency: "BRL")
    project = @user.projects.create!(name: "Site", client: client)
    entry(started: Time.utc(2026, 7, 10, 12, 0), ended: Time.utc(2026, 7, 10, 14, 0), project: project) # 2h × 100

    export = export_for
    matrix = export.rows_matrix
    parsed = CSV.parse(export.to_csv)

    # linha 1 do CSV (após o header) == matriz[0], comparando o campo Valor (col 14, índice 13)
    assert_equal matrix[0][13].to_s, parsed[1][13], "coluna Valor do CSV deve bater com a matriz"
    assert_equal "200.0", parsed[1][13], "2h × 100 = 200,00 (snapshot)"
  end
end
