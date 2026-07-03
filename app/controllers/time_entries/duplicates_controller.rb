# Duplicate de TimeEntry (Fatia 3.3 — Q47/Q13). Re-dispara um entry FINALIZADO:
# copia descrição/projeto/task/billable pra INICIAR um timer novo rodando AGORA (não
# copia horários). Ação sem verbo padrão isolada em resource próprio (STYLE.md).
# Lê o entry-fonte na bolha do user (isolamento Q23 → 404 pra alheio) — a cópia é
# server-authoritative, não confia em valores vindos do cliente. Timer único por user
# (Q3/Q4): se já houver um rodando → 409, sem stop implícito (a UI re-sincroniza).
module TimeEntries
  class DuplicatesController < ApplicationController
    include TrackerData

    before_action :set_source

    def create
      authorize! TimeEntry, to: :create?

      if current_timer
        @time_entry = current_timer
        @form_time_entry = nil
        render_timer_conflict
      else
        @time_entry = authorized_scope(TimeEntry.all).new(@source.attributes_for_restart.merge(started_at: Time.current))

        if @time_entry.save
          load_tracker_day_groups
          @form_time_entry = nil
          respond_to do |format|
            format.turbo_stream { render "timers/update", status: :created }
            format.html { redirect_to home_path(page: tracker_page_param), notice: "Timer iniciado." }
            format.json { render "time_entries/show", status: :created }
          end
        else
          @form_time_entry = @time_entry
          invalid_entry = @time_entry
          @time_entry = nil
          load_tracker_day_groups
          respond_to do |format|
            format.turbo_stream { render "timers/update", status: :unprocessable_entity }
            format.html { redirect_to home_path(page: tracker_page_param), alert: invalid_entry.errors.full_messages.to_sentence }
            format.json { render json: { errors: invalid_entry.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end
    rescue ActiveRecord::RecordNotUnique
      @time_entry = current_timer
      @form_time_entry = nil
      render_timer_conflict
    end

    private
      def set_source
        @source = authorized_scope(TimeEntry.all).find(params[:time_entry_id])
        authorize! @source, to: :show?
      end

      def current_timer
        authorized_scope(TimeEntry.all).find_by(ended_at: nil)
      end

      def render_timer_conflict
        flash.now[:alert] = "Timer já está rodando."
        load_tracker_day_groups
        respond_to do |format|
          format.turbo_stream { render "timers/update", status: :conflict }
          format.html { redirect_to home_path(page: tracker_page_param), alert: "Timer já está rodando." }
          format.json { render json: { error: "timer já está rodando" }, status: :conflict }
        end
      end
  end
end
