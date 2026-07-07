# CRUD de TimeEntry (Fatia 3.1). Controller fino: escopo por Current.user via
# `authorized_scope`, autorização via policy e lógica de start/stop mantida FORA
# daqui no `TimersController`.
class TimeEntriesController < ApplicationController
  layout "app"
  include TrackerData

  before_action :set_time_entry, only: %i[show edit update destroy]

  def index
    authorize! TimeEntry, to: :index?
    @time_entries = authorized_scope(TimeEntry.all).includes(:tags).order(started_at: :desc)

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
          # Render isolado da linha (ex.: Cancelar da edição): fora do grupo do dia
          # não há overlapping_ids calculado — consulta a sobreposição DESTA entry
          # direto (exists?, barato), senão o badge sumia com o conflito de pé.
          overlapping = @time_entry.overlapping_entries.exists? ? Set[@time_entry.id] : Set.new
          render partial: "time_entries/frame",
                 locals: { time_entry: @time_entry, overlapping_ids: overlapping },
                 layout: false
        end
      end
      format.json { render :show }
    end
  end

  def create
    authorize! TimeEntry, to: :create?
    @time_entry = authorized_scope(TimeEntry.all).new

    if save_time_entry_with_tags(@time_entry, time_entry_create_params)
      load_tracker_day_groups
      @manual_entry = TimeEntry.new
      respond_to do |format|
        format.turbo_stream { render :create, status: :created }
        format.html { redirect_to home_path(page: tracker_page_param), notice: t("time_entries.create.created") }
        format.json { render :show, status: :created }
      end
    else
      @manual_entry = @time_entry
      load_tracker_day_groups
      respond_to do |format|
        format.turbo_stream { render :create, status: :unprocessable_entity }
        format.html { redirect_to home_path(page: tracker_page_param), alert: @time_entry.errors.full_messages.to_sentence }
        format.json { render_errors(@time_entry) }
      end
    end
  end

  def update
    if save_time_entry_with_tags(@time_entry, time_entry_update_params)
      load_tracker_day_groups
      respond_to do |format|
        format.turbo_stream
        format.html do
          if turbo_frame_request?
            render partial: "time_entries/frame", locals: { time_entry: @time_entry }, layout: false
          else
            redirect_to home_path(page: tracker_page_param), notice: t("time_entries.update.updated")
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
      format.html { redirect_to home_path(page: tracker_page_param), notice: t("time_entries.destroy.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_time_entry
      @time_entry = authorized_scope(TimeEntry.all).find(params[:id])
      authorize! @time_entry
    end

    def time_entry_create_params
      attrs = params.require(:time_entry).permit(:project_id, :task_id, :description, :started_at, :ended_at, :billable, tag_ids: [], new_tag_names: [])
      # Início/fim vêm do datetime-local no FUSO do user (Q23b); convertê-los pra UTC
      # antes de gravar (o banco é UTC). Mesmo parse do update.
      attrs[:started_at] = parse_user_datetime(attrs[:started_at]) if attrs[:started_at].present?
      attrs[:ended_at] = parse_user_datetime(attrs[:ended_at]) if attrs[:ended_at].present?
      attrs
    end

    def time_entry_update_params
      attrs = params.require(:time_entry).permit(:project_id, :task_id, :description, :billable, :started_at, :ended_at, tag_ids: [], new_tag_names: [])
      # Q49(c): entry rodando só pode parar pelo stop; edição inline não carimba fim.
      attrs.delete(:ended_at) unless @time_entry.ended_at?
      attrs[:started_at] = parse_user_datetime(attrs[:started_at]) if attrs[:started_at].present?
      attrs[:ended_at] = parse_user_datetime(attrs[:ended_at]) if attrs[:ended_at].present?
      attrs
    end

    def render_errors(time_entry)
      render json: { errors: time_entry.errors.full_messages }, status: :unprocessable_entity
    end

    def parse_user_datetime(value)
      return value if value.match?(/[zZ]|[+-]\d{2}:\d{2}\z/)

      (ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone).parse(value)
    end

    def save_time_entry_with_tags(time_entry, attrs)
      tag_ids = Array(attrs.delete(:tag_ids))
      new_tag_names = Array(attrs.delete(:new_tag_names))

      time_entry.assign_attributes(attrs)
      return false unless time_entry.valid?

      saved = false
      TimeEntry.transaction do
        time_entry.save!
        unless sync_time_entry_tags(time_entry, tag_ids:, new_tag_names:)
          raise ActiveRecord::Rollback
        end
        saved = true
      end
      saved
    end

    def sync_time_entry_tags(time_entry, tag_ids:, new_tag_names:)
      tags = tags_from_ids(tag_ids)
      return false if time_entry.errors.any?

      tags += tags_from_names(new_tag_names)
      time_entry.tags = tags.uniq
      true
    end

    def tags_from_ids(tag_ids)
      ids = tag_ids.map(&:to_s).reject(&:blank?)
      return [] if ids.empty?

      tags = Current.user.tags.where(id: ids).to_a
      return tags if tags.size == ids.uniq.size

      @time_entry.errors.add(:tags, :not_owned)
      []
    end

    def tags_from_names(new_tag_names)
      new_tag_names
        .map { |name| name.to_s.strip }
        .reject(&:blank?)
        .uniq { |name| Tag.normalize_name(name) }
        .map do |name|
          Current.user.tags.find_by(name_normalized: Tag.normalize_name(name)) ||
            Current.user.tags.create!(name: name)
        end
    end
end
