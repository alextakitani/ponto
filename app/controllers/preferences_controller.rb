class PreferencesController < ApplicationController
  layout "app"

  before_action :set_preferences

  def show
  end

  def update
    attributes = user_params

    if invalid_time_zone?(attributes[:time_zone])
      @profile_errors = [ "Fuso horário inválido." ]
      render :show, status: :unprocessable_entity
    elsif Current.user.update(attributes)
      redirect_to preferences_path, notice: "Preferências atualizadas."
    else
      @profile_errors = Current.user.errors.full_messages
      render :show, status: :unprocessable_entity
    end
  end

  private
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
      params.require(:user).permit(:name, :time_zone)
    end

    def invalid_time_zone?(time_zone)
      # blank = chave omitida no PATCH parcial → não é "inválido", só não muda o fuso.
      # ⚠️ TimeZone[nil] LEVANTA ArgumentError no Rails 8.1 (não retorna nil).
      return false if time_zone.blank?

      ActiveSupport::TimeZone[time_zone].nil?
    end
end
