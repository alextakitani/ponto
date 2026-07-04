require "csv"

class Report
  # Export do relatório (Fatia 5.2) — o ENTREGÁVEL PRINCIPAL: a planilha que o usuário
  # anexa à fatura do cliente. Consome o Report (NÃO recalcula nada — Q58) e monta UMA
  # matriz (headers + linhas) da qual saem xlsx (caxlsx) E csv (stdlib CSV). Uma matriz,
  # dois formatos → os números batem por construção (Q20).
  #
  # Detailed (Q19): uma linha por entry, 14 colunas fixas. Datas/números são valores
  # NATIVOS (Date/Float) — no xlsx viram data/número somável; no csv, texto ISO/decimal.
  #
  # Moeda (Q19a): assume MOEDA ÚNICA por export → código no header ("Valor (BRL)"). Se o
  # período tiver MIX (`totals.multiple_currencies?`), FAZ O SIMPLES: header genérico
  # ("Valor") + coluna "Moeda" (15ª) com o código por linha. Sem abas por moeda.
  #
  # ESCOPO (Q21/D): esta Fatia entrega o DETAILED export (a matriz linha-a-linha, o
  # anexo da fatura). O SUMMARY export (a árvore agrupada TÍTULO|DURAÇÃO|AMOUNT vira uma
  # matriz com indentação) é MENOS crítico e fica como TODO — a lógica é distinta o
  # bastante (flatten recursivo dos groups + subtotais por moeda) pra não caber no mesmo
  # esforço sem arriscar o Detailed. O usuário exporta o Detailed e soma/agrupa no Excel.
  # TODO(fase relatórios): Report::Export#summary_matrix a partir de `report.groups`.
  class Export
    include ActionView::Helpers::NumberHelper

    # As 14 colunas do Detailed (Q19), nesta ordem.
    def initialize(report)
      @report = report
    end

    # Cabeçalho da matriz. Mono-moeda: valores com o código no header. Mix: header
    # genérico + coluna "Moeda" no fim.
    def headers
      value_headers =
        if multiple_currencies?
          [ t("reports.export.headers.hourly_rate"), t("reports.export.headers.amount") ]
        else
          suffix = " (#{export_currency})"
          [ "#{t("reports.export.headers.hourly_rate")}#{suffix}", "#{t("reports.export.headers.amount")}#{suffix}" ]
        end

      base = base_headers + value_headers
      multiple_currencies? ? base + [ t("reports.export.headers.currency") ] : base
    end

    # A MATRIZ: uma linha por entry (started_at DESC, herdado do Report). Valores nativos
    # (Date/Float/String) — xlsx e csv consomem a MESMA coisa.
    def rows_matrix
      @report.rows.map { |row| build_row(row) }
    end

    # CSV (stdlib): datas ISO, números decimais. Texto legível/importável.
    def to_csv
      CSV.generate do |csv|
        csv << headers
        rows_matrix.each { |row| csv << row.map { |cell| csv_cell(cell) } }
      end
    end

    # Package caxlsx em memória (o controller manda `to_stream`; os testes afERem células).
    # Header em negrito; datas com style de data; a matriz alimenta as células como estão.
    def to_xlsx_package
      package = Axlsx::Package.new
      workbook = package.workbook

      workbook.add_worksheet(name: t("reports.export.sheet_name")) do |sheet|
        header_style = workbook.styles.add_style(b: true)
        date_style = workbook.styles.add_style(format_code: "yyyy-mm-dd")

        sheet.add_row(headers, style: header_style)
        rows_matrix.each do |row|
          sheet.add_row(row, style: row_styles(row, date_style))
        end
      end

      package
    end

    # Bytes do .xlsx (pro send_data).
    def to_xlsx
      to_xlsx_package.to_stream.read
    end

    private
      # Uma linha da matriz. As colunas seguem a ordem da Q19 (ver BASE_HEADERS).
      def build_row(row)
        cells = [
          row.project&.name.to_s,          # 1 Projeto
          row.client&.name.to_s,           # 2 Cliente
          row.description.to_s,            # 3 Descrição
          row.task&.name.to_s,             # 4 Tarefa
          row.tags.map(&:name).sort.join(", "), # 5 Tags
          row.billable? ? t("common.yes") : t("common.no"),  # 6 Faturável
          local_date(row.started_at),      # 7 Data início (Date local)
          local_time(row.started_at),      # 8 Hora início (HH:MM local)
          local_date(row.ended_at),        # 9 Data fim
          local_time(row.ended_at),        # 10 Hora fim
          duration_hms(row.duration_seconds),      # 11 Duração HH:MM:SS
          duration_decimal(row.duration_seconds),  # 12 Duração decimal (Float somável)
          rate_number(row.rate_cents),     # 13 Valor/hora (Float ou "" se sem rate)
          amount_number(row.amount_cents)  # 14 Valor (Float)
        ]
        multiple_currencies? ? cells + [ row.currency ] : cells
      end

      # Estilos por célula do xlsx: as colunas de DATA (índices 6 e 8) ganham date_style
      # pra o Excel enxergar data real; o resto sem estilo (número/texto nativos).
      def row_styles(row, date_style)
        row.each_index.map { |i| [ 6, 8 ].include?(i) ? date_style : nil }
      end

      def base_headers
        [
          t("reports.export.headers.project"),
          t("reports.export.headers.client"),
          t("reports.export.headers.description"),
          t("reports.export.headers.task"),
          t("reports.export.headers.tags"),
          t("reports.export.headers.billable"),
          t("reports.export.headers.start_date"),
          t("reports.export.headers.start_time"),
          t("reports.export.headers.end_date"),
          t("reports.export.headers.end_time"),
          t("reports.export.headers.duration_h"),
          t("reports.export.headers.duration_decimal")
        ]
      end

      def t(key, **options)
        I18n.t(key, **options)
      end

      # No CSV, Date/Time viram ISO; o resto vira string via CSV padrão.
      def csv_cell(cell)
        cell.is_a?(Date) ? cell.iso8601 : cell
      end

      def local_date(timestamp)
        timestamp.in_time_zone(time_zone).to_date
      end

      def local_time(timestamp)
        timestamp.in_time_zone(time_zone).strftime("%H:%M")
      end

      def duration_hms(seconds)
        total = seconds.to_i
        format("%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
      end

      # Horas decimais pra somar no Excel (ex.: 1h25 → 1.42). 2 casas.
      def duration_decimal(seconds)
        (seconds.to_i / 3600.0).round(2)
      end

      # Valor/hora como NÚMERO (rate_cents/100). "" quando não há rate (não confundir 0).
      def rate_number(rate_cents)
        return "" if rate_cents.nil?

        (rate_cents / 100.0).round(2)
      end

      # Valor (amount) como NÚMERO. amount_cents vem do Report (snapshot/rounding — Q10).
      def amount_number(amount_cents)
        (amount_cents.to_i / 100.0).round(2)
      end

      # Moeda do export quando mono: a que aparece nos amounts; senão o default do app.
      def export_currency
        @report.totals.amounts.keys.first || Money.default_currency.iso_code
      end

      def multiple_currencies?
        @report.totals.multiple_currencies?
      end

      def time_zone
        ActiveSupport::TimeZone[@report.user.time_zone] || Time.zone
      end
  end
end
