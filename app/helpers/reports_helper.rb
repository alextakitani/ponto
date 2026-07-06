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

  # Amounts por MOEDA (Q43): nunca soma moedas diferentes. Recebe o Hash currency=>cents
  # (de Totals#amounts ou Group#amounts) e devolve uma string "R$ X · € Y". Vazio → "—".
  def report_amounts(amounts)
    return content_tag(:span, t("common.none"), class: "muted") if amounts.blank?

    parts = amounts.map { |currency, cents| humanized_money_with_symbol(Money.new(cents, currency)) }
    safe_join(parts, content_tag(:span, t("common.middle_dot"), class: "muted", "aria-hidden": true))
  end

  # Rótulo humano do período ativo (pra o header e as setas).
  def report_period_label(period)
    zone = tracker_time_zone
    first = period.first_date.strftime("%d/%m/%Y")
    last = period.last_date.strftime("%d/%m/%Y")
    first == last ? first : "#{first} – #{last}"
  end

  # Merge dos params atuais com overrides, preservando período/filtros/rounding na URL
  # (pra as setas, abas e o futuro botão de export herdarem tudo — Q58).
  def report_url(overrides = {})
    reports_path(request.query_parameters.deep_symbolize_keys.merge(overrides))
  end

  # URL do export no MESMO recorte da tela (Q58/Q20): herda período/filtros/rounding da
  # URL atual, só troca a extensão (:xlsx/:csv). O botão "Exportar" aponta pra cá.
  def report_export_url(format:)
    params = request.query_parameters.deep_symbolize_keys.merge(format: format)
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
