class PreferencesController < ApplicationController
  layout "app"

  before_action :set_preferences

  def show
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
