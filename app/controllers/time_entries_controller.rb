# CRUD de TimeEntry (Fatia 3.1). Controller fino: escopo por Current.user via
# `authorized_scope`, autorização via policy e lógica de start/stop mantida FORA
# daqui no `TimersController`.
class TimeEntriesController < ApplicationController
  layout "app"
  include TrackerData

  before_action :set_time_entry, only: %i[show edit update destroy]

  def index
    authorize! TimeEntry, to: :index?
    @time_entries = authorized_scope(TimeEntry.all).order(started_at: :desc)

    respond_to do |format|
      format.html { redirect_to home_path }
      format.json { render :index }
    end
  end

  def edit
  end

  def show
    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render partial: "time_entries/frame", locals: { time_entry: @time_entry }, layout: false
        end
      end
      format.json { render :show }
    end
  end

  def create
    authorize! TimeEntry, to: :create?
    @time_entry = authorized_scope(TimeEntry.all).new(time_entry_create_params)

    if @time_entry.save
      load_tracker_day_groups
      @manual_entry = TimeEntry.new
      respond_to do |format|
        format.turbo_stream { render :create, status: :created }
        format.html { redirect_to home_path, notice: "Entrada criada." }
        format.json { render :show, status: :created }
      end
    else
      @manual_entry = @time_entry
      load_tracker_day_groups
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html { redirect_to home_path, alert: @time_entry.errors.full_messages.to_sentence }
        format.json { render_errors(@time_entry) }
      end
    end
  end

  def update
    if @time_entry.update(time_entry_update_params)
      respond_to do |format|
        format.html do
          if turbo_frame_request?
            render partial: "time_entries/frame", locals: { time_entry: @time_entry }, layout: false
          else
            redirect_to home_path, notice: "Entrada atualizada."
          end
        end
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_errors(@time_entry) }
      end
    end
  end

  def destroy
    @time_entry.destroy
    load_tracker_day_groups
    @current_timer = authorized_scope(TimeEntry.all).find_by(ended_at: nil)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to home_path, notice: "Entrada removida." }
      format.json { head :no_content }
    end
  end

  private
    def set_time_entry
      @time_entry = authorized_scope(TimeEntry.all).find(params[:id])
      authorize! @time_entry
    end

    def time_entry_create_params
      attrs = params.require(:time_entry).permit(:project_id, :task_id, :description, :started_at, :ended_at, :billable)
      # Início/fim vêm do datetime-local no FUSO do user (Q23b); convertê-los pra UTC
      # antes de gravar (o banco é UTC). Mesmo parse do update.
      attrs[:started_at] = parse_user_datetime(attrs[:started_at]) if attrs[:started_at].present?
      attrs[:ended_at] = parse_user_datetime(attrs[:ended_at]) if attrs[:ended_at].present?
      attrs
    end

    def time_entry_update_params
      permitted = [ :project_id, :task_id, :description, :billable, :started_at ]
      permitted << :ended_at if @time_entry.ended_at?
      attrs = params.require(:time_entry).permit(*permitted)
      attrs[:started_at] = parse_user_datetime(attrs[:started_at]) if attrs[:started_at].present?
      attrs
    end

    def render_errors(time_entry)
      render json: { errors: time_entry.errors.full_messages }, status: :unprocessable_entity
    end

    def parse_user_datetime(value)
      return value if value.match?(/[zZ]|[+-]\d{2}:\d{2}\z/)

      (ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone).parse(value)
    end
end
