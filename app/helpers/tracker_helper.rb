module TrackerHelper
  def tracker_day_label(date)
    date.strftime("%d/%m/%Y")
  end

  def tracker_duration(seconds)
    total_seconds = seconds.to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    remainder = total_seconds % 60

    format("%02d:%02d:%02d", hours, minutes, remainder)
  end

  def tracker_entry_description(time_entry)
    time_entry.description.presence || "Sem descrição"
  end

  def tracker_entry_project_name(time_entry)
    time_entry.project&.name || "(sem projeto)"
  end

  def tracker_entry_time_range(time_entry)
    started = tracker_local_time(time_entry.started_at)
    ended = time_entry.ended_at? ? tracker_local_time(time_entry.ended_at) : "Rodando"

    "#{started} - #{ended}"
  end

  def tracker_entry_tags(time_entry)
    time_entry.tags.to_a.sort_by { |tag| [ tag.archived? ? 1 : 0, tag.name.downcase ] }
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
      .sort_by { |project| [ project.client&.name.to_s.downcase, project.name.downcase ] }
      .group_by { |project| project.client&.name || "(sem cliente)" }
      .map do |client_name, projects|
        [ client_name, projects.map { |project| [ project.name, project.id ] } ]
      end
  end

  def tracker_available_tags_for(time_entry)
    tags = Current.user.tags.active.to_a
    tags += time_entry.tags.archived.to_a if time_entry.persisted?
    tags.uniq.sort_by(&:name)
  end

  def tracker_local_time(timestamp)
    timestamp.in_time_zone(tracker_time_zone).strftime("%H:%M")
  end

  def tracker_time_zone
    ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone
  end
end
