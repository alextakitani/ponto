module TrackerData
  extend ActiveSupport::Concern

  TRACKER_PAGE_LIMIT = 50

  included do
    helper_method :tracker_next_page_params
  end

  private
    def tracker_relation
      authorized_scope(TimeEntry.all)
        .includes(:tags, project: :client)
        .order(started_at: :desc, id: :desc)
    end

    def load_tracker_day_groups
      @tracker_pagy, @tracker_entries_page = pagy(:offset, tracker_relation, limit: TRACKER_PAGE_LIMIT)
      @tracker_day_groups = tracker_day_groups(@tracker_entries_page)
      @tracker_has_more = @tracker_pagy.next.present?
    end

    def tracker_day_groups(entries, now: Time.current)
      time_zone = ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone

      entries
        .group_by { |entry| tracker_group_date(entry, time_zone, now:) }
        .sort_by { |date, _entries| -date.jd }
        .map do |date, day_entries|
          sorted_entries = day_entries.sort_by do |entry|
            [ entry.ended_at? ? 1 : 0, -entry.started_at.to_i ]
          end

          {
            date: date,
            entries: sorted_entries,
            total_seconds: sorted_entries.sum { |entry| tracker_elapsed_seconds(entry, now:) },
            amounts: tracker_day_amounts(sorted_entries)
          }
        end
    end

    # Somatória de valores faturáveis do dia, POR MOEDA (Q43): nunca soma moedas
    # diferentes — devolve um Hash currency => cents. O amount de uma entry já respeita
    # billable + rate presente (billable_amount é nil fora disso). Entry rodando não
    # entra (billable_amount só existe com ended_at, como no report — Q57).
    def tracker_day_amounts(entries)
      amounts = Hash.new(0)

      entries.each do |entry|
        money = entry.billable_amount
        amounts[money.currency.iso_code] += money.cents if money&.positive?
      end

      amounts
    end

    def tracker_next_page_params(day_group = @tracker_day_groups.last)
      return {} unless @tracker_pagy&.next

      params.permit(:page).to_h.merge(
        page: @tracker_pagy.next,
        last_date: day_group&.fetch(:date)
      ).compact
    end

    def tracker_day_total_seconds(date, now: Time.current)
      return unless date

      tracker_entries_on(date, now:).sum { |entry| tracker_elapsed_seconds(entry, now:) }
    end

    # Amounts do dia INTEIRO (não só a página) — usado pelo "Carregar mais" pra
    # reatualizar o valor do cabeçalho do dia contínuo junto com o total de horas.
    def tracker_day_total_amounts(date, now: Time.current)
      return {} unless date

      tracker_day_amounts(tracker_entries_on(date, now:))
    end

    def tracker_entries_on(date, now: Time.current)
      time_zone = ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone

      authorized_scope(TimeEntry.all).where(user: Current.user).select do |entry|
        tracker_group_date(entry, time_zone, now:) == date
      end
    end

    def tracker_page_param
      page = params[:page].to_i
      page.positive? ? page : nil
    end

    def tracker_elapsed_seconds(entry, now: Time.current)
      return entry.duration_seconds.to_i if entry.ended_at?

      [ now.to_i - entry.started_at.to_i, 0 ].max
    end

    def tracker_group_date(entry, time_zone, now: Time.current)
      # Q6: o entry pertence INTEIRO ao dia do started_at (no fuso do user), sem
      # fatiar na meia-noite — inclusive o que está rodando (não cai no "hoje").
      entry.started_at.in_time_zone(time_zone).to_date
    end
end
