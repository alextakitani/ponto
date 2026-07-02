module TrackerData
  extend ActiveSupport::Concern

  private
    def tracker_relation
      authorized_scope(TimeEntry.all).includes(project: :client)
    end

    def load_tracker_day_groups
      @tracker_day_groups = tracker_day_groups
    end

    def tracker_day_groups(now: Time.current)
      time_zone = ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone

      tracker_relation.to_a
        .group_by { |entry| tracker_group_date(entry, time_zone, now:) }
        .sort_by { |date, _entries| -date.jd }
        .map do |date, day_entries|
          sorted_entries = day_entries.sort_by do |entry|
            [ entry.ended_at? ? 1 : 0, -entry.started_at.to_i ]
          end

          {
            date: date,
            entries: sorted_entries,
            total_seconds: sorted_entries.sum { |entry| tracker_elapsed_seconds(entry, now:) }
          }
        end
    end

    def tracker_elapsed_seconds(entry, now: Time.current)
      return entry.duration_seconds.to_i if entry.ended_at?

      [ now.to_i - entry.started_at.to_i, 0 ].max
    end

    def tracker_group_date(entry, time_zone, now: Time.current)
      if entry.ended_at?
        entry.started_at.in_time_zone(time_zone).to_date
      else
        now.in_time_zone(time_zone).to_date
      end
    end
end
