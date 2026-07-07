class PreferencesController < ApplicationController
  layout "app"

  # O setup pesado (400+ fusos, tokens) só serve o form HTML; o JSON (contrato da
  # extensão/CLI, autenticado por Bearer como os demais resources) só precisa do
  # Current.user — evita a query e a montagem à toa numa request de API.
  before_action :set_preferences, unless: -> { action_name == "show" && request.format.json? }

  # GET /preferences — HTML: o form de Preferências. JSON: as preferências do
  # usuário autenticado (locale/theme/accent/time_zone/export_locale), pra a
  # extensão/CLI espelharem a config sem uma tela dedicada (07/07).
  def show
    respond_to do |format|
      format.html
      format.json # app/views/preferences/show.json.jbuilder
    end
  end

  def update
    attributes = user_params

    if invalid_time_zone?(attributes[:time_zone])
      @profile_errors = [ t("preferences.update.invalid_time_zone") ]
      render :show, status: :unprocessable_entity
    elsif Current.user.update(attributes)
      # return_to (ajustes rápidos da welcome): volta pra origem SEM o flash de
      # "atualizado" — um toggle de idioma/tema não é o mesmo que salvar o form.
      if (destination = safe_return_to)
        redirect_to destination
      else
        redirect_to preferences_path, notice: t("preferences.update.updated")
      end
    else
      @profile_errors = Current.user.errors.full_messages
      Current.user.reload
      render :show, status: :unprocessable_entity
    end
  end

  private
    # return_to só pode ser um caminho INTERNO relativo (começa com "/", não "//"):
    # nunca um host externo (anti open-redirect). Qualquer outra coisa → nil.
    def safe_return_to
      candidate = params[:return_to].to_s
      candidate if candidate.start_with?("/") && !candidate.start_with?("//")
    end

    def set_preferences
      @user = Current.user
      @access_tokens = @user.access_tokens.order(created_at: :desc)
      @time_zone_options = ActiveSupport::TimeZone.all.map do |zone|
        [ zone.to_s, zone.tzinfo.name ]
      end
      @profile_errors ||= []
      @access_token_errors ||= []
    end

    def user_params
      params.require(:user).permit(:name, :time_zone, :theme, :locale, :export_locale, :accent)
    end

    def invalid_time_zone?(time_zone)
      # blank = chave omitida no PATCH parcial → não é "inválido", só não muda o fuso.
      # ⚠️ TimeZone[nil] LEVANTA ArgumentError no Rails 8.1 (não retorna nil).
      return false if time_zone.blank?

      ActiveSupport::TimeZone[time_zone].nil?
    end
end
