# Timer singular atual (Fatia 3.1). Toda a lógica de start/stop mora AQUI:
# `POST /timer` inicia, `DELETE /timer` para, e `GET /timer` sincroniza o estado
# real do user logado. A invariante "um rodando por user" é reforçada no banco.
class TimersController < ApplicationController
  def show
    @time_entry = current_timer

    respond_to do |format|
      format.html { redirect_to time_entries_path }
      format.json { render :show }
    end
  end

  def create
    authorize! TimeEntry, to: :create?

    if current_timer
      render_timer_conflict
    else
      @time_entry = authorized_scope(TimeEntry.all).new(timer_params.merge(started_at: Time.current))

      if @time_entry.save
        respond_to do |format|
          format.html { redirect_to time_entries_path, notice: "Timer iniciado." }
          format.json { render "time_entries/show", status: :created }
        end
      else
        respond_to do |format|
          format.html { redirect_to time_entries_path, alert: @time_entry.errors.full_messages.to_sentence }
          format.json { render_errors(@time_entry) }
        end
      end
    end
  rescue ActiveRecord::RecordNotUnique
    render_timer_conflict
  end

  def destroy
    if @time_entry = current_timer
      stopped_at = Time.current
      @time_entry.stop_at(stopped_at)
      deleted = @time_entry.destroyed?

      respond_to do |format|
        format.html do
          redirect_to time_entries_path, notice: deleted ? "Timer descartado." : "Timer parado."
        end
        format.json do
          if deleted
            head :no_content
          else
            render "time_entries/show"
          end
        end
      end
    else
      respond_to do |format|
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
      respond_to do |format|
        format.html { redirect_to time_entries_path, alert: "Timer já está rodando." }
        format.json { render json: { error: "timer já está rodando" }, status: :conflict }
      end
    end

    def render_errors(time_entry)
      render json: { errors: time_entry.errors.full_messages }, status: :unprocessable_entity
    end
end
