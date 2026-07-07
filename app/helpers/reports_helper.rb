module ReportsHelper
  # Duração HH:MM:SS (reusa o formatter do tracker — mesma matriz visual, tabular-nums).
  def report_duration(seconds)
    tracker_duration(seconds)
  end

  # Data + hora no fuso do user, sem depender de I18n.l (não há formato :short definido
  # nos locales — o app formata datas via strftime, como o tracker).
  def report_datetime(timestamp)
    timestamp.in_time_zone(tracker_time_zone).strftime("%d/%m %H:%M")
  end

  # Só a hora, no fuso do user (coluna de tempo e tooltip das barras).
  def report_time(timestamp)
    timestamp.in_time_zone(tracker_time_zone).strftime("%H:%M")
  end

  # Coluna de tempo estilo Clockify (pedido 07/07): horários numa linha
  # ("10:21 – 16:51") e a data embaixo, subtle. Cruzou a meia-noite → a linha de
  # data vira intervalo ("05/07 – 06/07/2026").
  def report_entry_times(row)
    "#{report_time(row.started_at)} – #{report_time(row.ended_at)}"
  end

  # nil no dia comum (a data vive no cabeçalho do grupo); intervalo quando o
  # entry cruza a meia-noite no fuso do user.
  def report_entry_date_range(row)
    ended_date = row.ended_at.in_time_zone(tracker_time_zone).to_date
    return if ended_date == row.date

    "#{l(row.date, format: :day_month)} – #{l(ended_date, format: :numeric)}"
  end

  # Amounts por MOEDA (Q43): nunca soma moedas diferentes. Recebe o Hash currency=>cents
  # (de Totals#amounts ou Group#amounts) e devolve uma string "R$ X · € Y". Vazio → "—".
  def report_amounts(amounts)
    return content_tag(:span, t("common.none"), class: "muted") if amounts.blank?

    parts = humanized_report_amounts(amounts)
    safe_join(parts, content_tag(:span, t("common.middle_dot"), class: "muted", "aria-hidden": true))
  end

  def report_amounts_text(amounts)
    humanized_report_amounts(amounts).join(" #{t("common.middle_dot")} ")
  end

  # Rótulo humano do período ativo. Preset de calendário ganha o NOME ("julho 2026",
  # "2026") em vez de duas datas completas — mais curto e escaneável (importa no
  # mobile). Semana/custom mostram o intervalo; dia único, a data.
  def report_period_label(period)
    case period.preset
    when "month", "last_month"
      l(period.first_date, format: "%B %Y")
    when "year", "last_year"
      period.first_date.year.to_s
    else
      first = l(period.first_date, format: :day_month)
      last = l(period.last_date, format: :numeric)
      period.first_date == period.last_date ? last : "#{first} – #{last}"
    end
  end

  # Merge dos params atuais com overrides, preservando período/filtros/rounding na URL
  # (pra as setas e o botão de export herdarem tudo — Q58).
  def report_url(overrides = {})
    reports_path(report_query_parameters.merge(overrides))
  end

  # URL do export no MESMO recorte da tela (Q58/Q20): herda período/filtros/rounding da
  # URL atual, só troca a extensão (:xlsx/:csv). O botão "Exportar" aponta pra cá.
  def report_export_url(format:)
    params = report_query_parameters.merge(format: format)
    export_reports_path(params)
  end

  # Geometria de UMA fatia do donut SVG (Q71): num círculo r=15.9155 a circunferência
  # é ~100, então stroke-dasharray = [fração*100, resto] e o offset acumula. Devolve
  # [dash, gap, offset] já em unidades de 0–100. Padrão idêntico ao donut da landing.
  def report_donut_segment(fraction, cumulative)
    dash = (fraction * 100).round(3)
    gap = (100 - dash).round(3)
    # O donut gira -90° no CSS (começa no topo); o offset é NEGATIVO do acumulado.
    offset = (-cumulative * 100).round(3)
    [ dash, gap, offset ]
  end

  # Altura relativa (%) de uma barra sobre o TOPO DO EIXO (não sobre o pico cru):
  # assim a barra mais alta não encosta no teto e alinha com as linhas de grade.
  def report_bar_height(bucket, axis_max_seconds)
    return 0 if axis_max_seconds.to_i.zero?

    ((bucket.duration_seconds.to_f / axis_max_seconds) * 100).round(2)
  end

  def report_bar_title(bucket)
    # Dia da semana abreviado antes da data ("dom, 05/07" — pedido 07/07); o %a
    # lê os abbr_day_names dos locales.
    title = "#{l(bucket.date, format: "%a, %d/%m")} — #{report_duration(bucket.duration_seconds)}"
    if bucket.duration_seconds.positive? && bucket.first_started_at && bucket.last_ended_at
      title = "#{title} · #{report_time(bucket.first_started_at)}–#{report_time(bucket.last_ended_at)}"
      title = "#{title} · #{report_amounts_text(bucket.amounts)}" if bucket.amounts.present?
    end

    title
  end

  def report_day_anchor_id(date)
    "report-day-#{date.iso8601}"
  end

  # Params ABSOLUTOS de um período (preset + âncora `from`; custom leva as duas
  # datas). Usado pelas setas ‹ › e pelo form de filtros — navegação RELATIVA
  # (nav= mergeado na URL corrente) era aplicada sempre sobre o período-base do
  # preset (bug 07/07: next→ago, prev→jun pulando jul), e o form de filtros
  # perdia o período por não reemitir os params dele.
  def report_period_params(period)
    {
      period: period.preset,
      from: period.first_date.iso8601,
      to: period.custom? ? period.last_date.iso8601 : nil,
      nav: nil
    }
  end

  # Eixo Y do gráfico de barras, estilo Clockify: o topo do eixo é o pico arredondado
  # pra cima num múltiplo "redondo" de horas, e devolvemos os ticks (marcações de hora
  # + a altura % de cada um) pra desenhar as linhas de grade. Zero → eixo vazio.
  #
  # Devolve { max_seconds:, ticks: [{ hours:, percent: }, ...] } — max_seconds é a base
  # comum que report_bar_height usa pra medir as barras (mesma escala do eixo).
  def report_bar_axis(peak_seconds, tick_count: 5)
    peak_hours = peak_seconds.to_f / 3600
    return { max_seconds: 0, ticks: [] } if peak_hours.zero?

    step = axis_step(peak_hours / tick_count)
    max_hours = (peak_hours / step).ceil * step
    max_hours = step if max_hours.zero?

    ticks = (1..(max_hours / step).round).map do |i|
      hours = (i * step).round(2)
      { hours: hours, percent: (hours.to_f / max_hours * 100).round(2) }
    end

    { max_seconds: (max_hours * 3600).round, ticks: ticks }
  end

  # Rótulo curto de horas pro eixo (ex.: "8h", "2.5h"). Inteiro sem casa decimal.
  def report_axis_hours(hours)
    formatted = (hours % 1).zero? ? hours.to_i.to_s : format("%.1f", hours)
    t("reports.bar_hours", hours: formatted)
  end

  private
    # Passo "redondo" pro eixo: sobe o intervalo bruto pro próximo valor amigável
    # (1, 2, 2.5, 5, 10…) pra as marcações não caírem em números quebrados.
    def axis_step(raw)
      candidates = [ 0.5, 1, 2, 2.5, 5, 10, 20, 50 ]
      candidates.find { |c| c >= raw } || raw.ceil
    end

    def humanized_report_amounts(amounts)
      amounts.map { |currency, cents| humanized_money_with_symbol(Money.new(cents, currency)) }
    end

    def report_query_parameters
      request.query_parameters.deep_symbolize_keys.except(:view)
    end

  public

  # Rótulo humano de uma dimensão de agrupamento (pro cabeçalho da tabela do Summary).
  def report_group_dimension_label(dimension)
    t("reports.group_dimensions.#{dimension}", default: t("reports.group_dimensions.group"))
  end

  def reports_group_options
    [
      [ t("common.none"), "" ],
      [ t("reports.group_dimensions.project"), "project" ],
      [ t("reports.group_dimensions.client"), "client" ],
      [ t("reports.group_dimensions.task"), "task" ],
      [ t("reports.group_dimensions.tag"), "tag" ],
      [ t("reports.group_dimensions.description"), "description" ]
    ]
  end

  # Fatias do donut POR PROJETO (Q21): agrupa as rows por projeto (cor do projeto;
  # "(sem projeto)" em cinza), calcula a fração de tempo de cada uma e devolve structs
  # {label, color, fraction, cumulative} prontos pro SVG. Ordenado por tempo desc.
  DonutSlice = Struct.new(:label, :color, :fraction, :cumulative, keyword_init: true)
  NO_PROJECT_COLOR = "var(--color-border-strong)".freeze

  def report_donut_slices(report)
    total = report.rows.sum(&:duration_seconds)
    return [] if total.zero?

    by_project = report.rows.group_by { |row| row.project }
    ordered = by_project.sort_by { |_project, rows| -rows.sum(&:duration_seconds) }

    cumulative = 0.0
    ordered.map do |project, rows|
      fraction = rows.sum(&:duration_seconds).to_f / total
      slice = DonutSlice.new(
        label: project&.name || t("tracker.no_project"),
        color: project&.color || NO_PROJECT_COLOR,
        fraction: fraction,
        cumulative: cumulative
      )
      cumulative += fraction
      slice
    end
  end
end
