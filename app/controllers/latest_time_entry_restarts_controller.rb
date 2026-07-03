class LatestTimeEntryRestartsController < ApplicationController
  include TrackerData

  def create
    authorize! TimeEntry, to: :create?

    if current_timer
      @time_entry = current_timer
      @form_time_entry = nil
      @latest_restart_entry = latest_finished_entry
      render_timer_conflict
    elsif (source = latest_finished_entry)
      @time_entry = authorized_scope(TimeEntry.all).new(source.attributes_for_restart.merge(started_at: Time.current))

      if @time_entry.save
        load_tracker_day_groups
        @form_time_entry = nil
        @latest_restart_entry = latest_finished_entry
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
        @latest_restart_entry = latest_finished_entry
        respond_to do |format|
          format.turbo_stream { render "timers/update", status: :unprocessable_entity }
          format.html { redirect_to home_path(page: tracker_page_param), alert: invalid_entry.errors.full_messages.to_sentence }
          format.json { render json: { errors: invalid_entry.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { head :not_found }
        format.html { redirect_to home_path(page: tracker_page_param), alert: "Nenhuma entrada anterior para retomar." }
        format.json { render json: { error: "entrada anterior não encontrada" }, status: :not_found }
      end
    end
  rescue ActiveRecord::RecordNotUnique
    @time_entry = current_timer
    @form_time_entry = nil
    @latest_restart_entry = latest_finished_entry
    render_timer_conflict
  end

  private
    def latest_finished_entry
      authorized_scope(TimeEntry.all).where.not(ended_at: nil).order(ended_at: :desc, id: :desc).first
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
