# Timer singular atual (Fatia 3.1). Toda a lógica de start/stop mora AQUI:
# `POST /timer` inicia, `DELETE /timer` para, e `GET /timer` sincroniza o estado
# real do user logado. A invariante "um rodando por user" é reforçada no banco.
class TimersController < ApplicationController
  include TrackerData

  def show
    @time_entry = current_timer
    @form_time_entry = TimeEntry.new

    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render :show, layout: false
        else
          redirect_to home_path
        end
      end
      format.json { render :show }
    end
  end

  def create
    authorize! TimeEntry, to: :create?

    if current_timer
      @time_entry = current_timer
      @form_time_entry = nil
      render_timer_conflict
    else
      @time_entry = authorized_scope(TimeEntry.all).new(timer_params.merge(started_at: Time.current))

      if @time_entry.save
        load_tracker_day_groups
        @form_time_entry = nil
        respond_to do |format|
          format.turbo_stream { render :update, status: :created }
          format.html { redirect_to home_path, notice: "Timer iniciado." }
          format.json { render "time_entries/show", status: :created }
        end
      else
        load_tracker_day_groups
        @form_time_entry = @time_entry
        invalid_entry = @time_entry
        @time_entry = nil
        respond_to do |format|
          format.turbo_stream { render :update, status: :unprocessable_entity }
          format.html { redirect_to home_path, alert: invalid_entry.errors.full_messages.to_sentence }
          format.json { render_errors(invalid_entry) }
        end
      end
    end
  rescue ActiveRecord::RecordNotUnique
    @time_entry = current_timer
    @form_time_entry = nil
    render_timer_conflict
  end

  def destroy
    if @time_entry = current_timer
      stopped_entry = @time_entry
      stopped_at = Time.current
      @time_entry.stop_at(stopped_at)
      deleted = @time_entry.destroyed?
      load_tracker_day_groups
      @current_timer = current_timer
      @form_time_entry = nil

      respond_to do |format|
        format.turbo_stream { render :update }
        format.html do
          redirect_to home_path, notice: deleted ? "Timer descartado." : "Timer parado."
        end
        format.json do
          if deleted
            head :no_content
          else
            @time_entry = stopped_entry
            render "time_entries/show"
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { head :not_found }
        format.html { head :not_found }
        format.json { render json: { error: "timer não encontrado" }, status: :not_found }
      end
    end
  end

  private
    def current_timer
      authorized_scope(TimeEntry.all).find_by(ended_at: nil)
    end

    def timer_params
      params.fetch(:timer, {}).permit(:project_id, :task_id, :description)
    end

    def render_timer_conflict
      load_tracker_day_groups
      respond_to do |format|
        format.turbo_stream { render :update, status: :conflict }
        format.html { redirect_to home_path, alert: "Timer já está rodando." }
        format.json { render json: { error: "timer já está rodando" }, status: :conflict }
      end
    end

    def render_errors(time_entry)
      render json: { errors: time_entry.errors.full_messages }, status: :unprocessable_entity
    end
end
