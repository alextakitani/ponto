class AccessTokensController < ApplicationController
  layout "app"

  def create
    @access_token = Current.user.access_tokens.new(access_token_params)

    if @access_token.save
      flash[:created_access_token] = @access_token.token
      redirect_to preferences_path, notice: "Token criado."
    else
      set_preferences
      @access_token_errors = @access_token.errors.full_messages
      render "preferences/show", status: :unprocessable_entity
    end
  end

  def destroy
    access_token = Current.user.access_tokens.find(params[:id])
    access_token.destroy

    redirect_to preferences_path, notice: "Token revogado."
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
end
