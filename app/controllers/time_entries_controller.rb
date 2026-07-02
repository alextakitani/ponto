# CRUD de TimeEntry (Fatia 3.1). Controller fino: escopo por Current.user via
# `authorized_scope`, autorização via policy e lógica de start/stop mantida FORA
# daqui no `TimersController`.
class TimeEntriesController < ApplicationController
  layout "app"

  before_action :set_time_entry, only: %i[show update destroy]

  def index
    authorize! TimeEntry, to: :index?
    @time_entries = authorized_scope(TimeEntry.all).order(started_at: :desc)

    respond_to do |format|
      format.html
      format.json { render :index }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render :show }
    end
  end

  def create
    authorize! TimeEntry, to: :create?
    @time_entry = authorized_scope(TimeEntry.all).new(time_entry_create_params)

    if @time_entry.save
      respond_to do |format|
        format.html { redirect_to time_entry_path(@time_entry), notice: "Entrada criada." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :index, status: :unprocessable_entity }
        format.json { render_errors(@time_entry) }
      end
    end
  end

  def update
    if @time_entry.update(time_entry_update_params)
      respond_to do |format|
        format.html { redirect_to time_entry_path(@time_entry), notice: "Entrada atualizada." }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.json { render_errors(@time_entry) }
      end
    end
  end

  def destroy
    @time_entry.destroy

    respond_to do |format|
      format.html { redirect_to time_entries_path, notice: "Entrada removida." }
      format.json { head :no_content }
    end
  end

  private
    def set_time_entry
      @time_entry = authorized_scope(TimeEntry.all).find(params[:id])
      authorize! @time_entry
    end

    def time_entry_create_params
      params.require(:time_entry).permit(:project_id, :task_id, :description, :started_at, :ended_at, :billable)
    end

    def time_entry_update_params
      permitted = [ :project_id, :task_id, :description, :billable, :started_at ]
      permitted << :ended_at if @time_entry.ended_at?
      params.require(:time_entry).permit(*permitted)
    end

    def render_errors(time_entry)
      render json: { errors: time_entry.errors.full_messages }, status: :unprocessable_entity
    end
end
