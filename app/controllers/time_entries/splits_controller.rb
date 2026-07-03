# Split de TimeEntry (Fatia 3.3 — Q48). Ação sem verbo padrão isolada em resource
# próprio (STYLE.md). Controller fino: acha o entry na bolha do user (isolamento Q23
# → 404 pra alheio), converte o corte do fuso do user pra UTC e delega a mecânica
# (transação, cópia fiel, re-snapshot) ao model `TimeEntry#split_at`. Erro de corte
# inválido (fora do intervalo / entry rodando) vira 422.
module TimeEntries
  class SplitsController < ApplicationController
    layout "app"
    include TrackerData

    before_action :set_time_entry

    def create
      @time_entry.split_at(cut_at)
      load_tracker_day_groups
      @current_timer = authorized_scope(TimeEntry.all).find_by(ended_at: nil)

      respond_to do |format|
        format.turbo_stream { render "time_entries/splits/create" }
        format.html { redirect_to home_path, notice: "Entrada dividida." }
        format.json { head :no_content }
      end
    rescue ArgumentError => e
      respond_to do |format|
        format.turbo_stream { render_split_error(e.message) }
        format.html { redirect_to home_path, alert: e.message }
        format.json { render json: { errors: [ e.message ] }, status: :unprocessable_entity }
      end
    end

    private
      def set_time_entry
        @time_entry = authorized_scope(TimeEntry.all).find(params[:time_entry_id])
        authorize! @time_entry, to: :update?
      end

      def cut_at
        raw = params.require(:split).permit(:cut)[:cut].to_s
        raise ArgumentError, "informe o ponto de corte" if raw.blank?

        parse_user_datetime(raw)
      end

      def parse_user_datetime(value)
        return value if value.match?(/[zZ]|[+-]\d{2}:\d{2}\z/)

        zone = ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone
        zone.parse(value) or raise ArgumentError, "ponto de corte inválido"
      end

      def render_split_error(message)
        load_tracker_day_groups
        @current_timer = authorized_scope(TimeEntry.all).find_by(ended_at: nil)
        flash.now[:alert] = message
        render "time_entries/splits/create", status: :unprocessable_entity
      end
  end
end
