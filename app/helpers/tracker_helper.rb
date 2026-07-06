require "set"

module TrackerHelper
  # Rótulo do cabeçalho de dia. "Hoje"/"Ontem" pros dois grupos mais acessados
  # (evita o usuário calcular a data toda sessão); data completa pros demais. O
  # "hoje" é relativo ao fuso do USER (Q6/Q23b), não ao do servidor — o próprio
  # agrupamento já corta o dia nesse fuso, então comparamos na mesma régua.
  def tracker_day_label(date)
    case date
    when tracker_today       then t("tracker.today")
    when tracker_today - 1   then t("tracker.yesterday")
    else "#{t('date.abbr_day_names')[date.wday]}, #{date.strftime(t('date.formats.numeric'))}"
    end
  end

  def tracker_duration(seconds)
    total_seconds = seconds.to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    remainder = total_seconds % 60

    format("%02d:%02d:%02d", hours, minutes, remainder)
  end

  def tracker_entry_description(time_entry)
    time_entry.description.presence || t("tracker.no_description")
  end

  def tracker_entry_project_name(time_entry)
    time_entry.project&.name || t("tracker.no_project")
  end

  def tracker_entry_time_range(time_entry)
    started = tracker_local_time(time_entry.started_at)
    ended = time_entry.ended_at? ? tracker_local_time(time_entry.ended_at) : t("tracker.running")

    "#{started} - #{ended}"
  end

  def tracker_entry_tags(time_entry)
    time_entry.tags.to_a.sort_by { |tag| [ tag.archived? ? 1 : 0, tag.name_normalized ] }
  end

  def tracker_overlapping_entry_ids(entries)
    finished_entries = entries.select { |entry| entry.id.present? && entry.ended_at.present? }
    overlapping_ids = Set.new

    finished_entries.combination(2) do |left, right|
      next unless left.started_at < right.ended_at && right.started_at < left.ended_at

      overlapping_ids << left.id
      overlapping_ids << right.id
    end

    overlapping_ids
  end

  def tracker_billable_amount(time_entry)
    amount = time_entry.billable_amount
    if amount
      amount.format
    else
      t("common.none")
    end
  end

  # Total de valores de um dia, POR MOEDA (Q43). Recebe o Hash currency => cents do
  # day_group e devolve "€ 133,18" (ou "R$ X · € Y" com várias moedas). Vazio → nil
  # (o cabeçalho do dia só mostra o valor quando há faturável — não polui com "—").
  def tracker_day_amounts(amounts)
    return if amounts.blank?

    parts = amounts.map { |currency, cents| Money.new(cents, currency).format }
    safe_join(parts, content_tag(:span, t("common.middle_dot"), class: "muted", "aria-hidden": true))
  end

  def tracker_datetime_local_value(timestamp)
    return if timestamp.blank?

    timestamp.in_time_zone(tracker_time_zone).strftime("%Y-%m-%dT%H:%M")
  end

  # Ponto de corte DEFAULT do split (Q48): o meio do intervalo, já no fuso do user e no
  # formato do datetime-local. Só faz sentido pra entry finalizado.
  def tracker_split_default(time_entry)
    return unless time_entry.ended_at?

    midpoint = time_entry.started_at + (time_entry.ended_at - time_entry.started_at) / 2
    tracker_datetime_local_value(midpoint)
  end

  def tracker_grouped_project_options
    Current.user.projects.active.includes(:client).to_a
      .sort_by { |project| [ project.client&.name_normalized.to_s, project.name_normalized ] }
      .group_by { |project| project.client&.name || t("tracker.no_client") }
      .map do |client_name, projects|
        [ client_name, projects.map { |project| [ project.name, project.id ] } ]
      end
  end

  def tracker_available_tags_for(time_entry)
    tags = Current.user.tags.active.to_a
    tags += time_entry.tags.archived.to_a if time_entry.persisted?
    tags.uniq.sort_by(&:name_normalized)
  end

  def tracker_local_time(timestamp)
    timestamp.in_time_zone(tracker_time_zone).strftime("%H:%M")
  end

  def tracker_time_zone
    ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone
  end

  # "Hoje" no fuso do user — a mesma régua que o agrupamento por dia usa (Q6/Q23b).
  def tracker_today
    Time.current.in_time_zone(tracker_time_zone).to_date
  end
end
