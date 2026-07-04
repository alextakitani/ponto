class AccessTokensController < ApplicationController
  layout "app"

  def create
    attributes = access_token_params
    # ⚠️ permission é enum: atribuir valor fora do range LEVANTA ArgumentError
    # (500) antes do save. Whitelist manual → renderiza 422 pra request forjado.
    unless AccessToken.permissions.key?(attributes[:permission])
      return render_create_error([ t("preferences.access_tokens.invalid_permission") ])
    end

    @access_token = Current.user.access_tokens.new(attributes)

    if @access_token.save
      flash[:created_access_token] = @access_token.token
      redirect_to preferences_path, notice: t("preferences.access_tokens.created")
    else
      render_create_error(@access_token.errors.full_messages)
    end
  end

  def destroy
    access_token = Current.user.access_tokens.find(params[:id])
    access_token.destroy

    redirect_to preferences_path, notice: t("preferences.access_tokens.revoked")
  end

  private
    def set_preferences
      @user = Current.user
      @access_tokens = @user.access_tokens.order(created_at: :desc)
      @time_zone_options = ActiveSupport::TimeZone.all.map do |zone|
        [ zone.to_s, zone.tzinfo.name ]
      end
      @profile_errors = []
    end

    def access_token_params
      params.require(:access_token).permit(:label, :permission)
    end

    def render_create_error(messages)
      set_preferences
      @access_token_errors = messages
      render "preferences/show", status: :unprocessable_entity
    end
end
