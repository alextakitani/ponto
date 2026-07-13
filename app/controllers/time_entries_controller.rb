# CRUD de TimeEntry (Fatia 3.1). Controller fino: escopo por Current.user via
# `authorized_scope`, autorização via policy e lógica de start/stop mantida FORA
# daqui no `TimersController`.
class TimeEntriesController < ApplicationController
  layout "app"
  include TrackerData
  include EntryTags

  before_action :set_time_entry, only: %i[show edit update destroy]

  def index
    authorize! TimeEntry, to: :index?
    # Paginado (Q73): sem LIMIT, um histórico grande puxava o array inteiro + um
    # N+1 de taggings de milhares de ids numa request só. `?page=`/`?limit=` no JSON.
    relation = authorized_scope(TimeEntry.all).includes(:tags).order(started_at: :desc, id: :desc)

    respond_to do |format|
      format.html { redirect_to home_path }
      format.json do
        relation = apply_time_entry_range(relation) or return
        @time_entries = paginate_json(relation)
        render :index
      end
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

    if save_entry_with_tags(@time_entry, time_entry_create_params)
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
    if save_entry_with_tags(@time_entry, time_entry_update_params)
      load_tracker_day_groups
      # A barra do timer precisa re-renderizar quando a entry EDITADA é a que está
      # rodando (mudou projeto/tag/started_at) — senão a lista atualiza mas a barra
      # fica com o conteúdo velho (bug do print). Só nesse caso: editar uma entry
      # PARADA não mexe na barra. Mesmo racional do destroy (@timer_bar_stale).
      @timer_bar_stale = @time_entry.ended_at.nil?
      @current_timer = @time_entry if @timer_bar_stale
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
    # A barra do timer só muda se a entry deletada era a RODANDO — deletar entry
    # parada não pode reescrever a barra (o rewrite re-anima o conteúdo e apaga o
    # que o usuário tiver digitado no form ocioso).
    @timer_bar_stale = @time_entry.ended_at.nil?
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
    # Filtro opcional por intervalo no GET /time_entries JSON (só JSON). `since` e
    # `until` são ISO 8601 combináveis; filtram por `started_at` no SQL (via scopes),
    # ANTES da paginação — então o X-Total-Count já reflete a janela. `until` é fim
    # EXCLUSIVO. Valor não-parseável → 400 `{error:}` (formato de erro da API): um
    # since/until malformado é bug do cliente, melhor falhar visível que devolver a
    # janela errada em silêncio. Sem os params, a relação passa intacta.
    # Retorna a relation, ou nil após já ter renderizado o 400 (o index dá `return`).
    def apply_time_entry_range(relation)
      if params[:since].present?
        since = parse_iso_timestamp(params[:since]) or return render_range_error(:since)
        relation = relation.started_since(since)
      end

      if params[:until].present?
        upto = parse_iso_timestamp(params[:until]) or return render_range_error(:until)
        relation = relation.started_before(upto)
      end

      relation
    end

    def parse_iso_timestamp(value)
      Time.iso8601(value)
    rescue ArgumentError
      nil
    end

    def render_range_error(param)
      render json: { error: "invalid #{param} timestamp" }, status: :bad_request
      nil
    end

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
end
