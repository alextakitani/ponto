class ApplicationController < ActionController::Base
  include Authentication
  include RequestForgeryProtection
  include ActionPolicy::Controller
  include SetLocale

  # Contexto de autorização do Action Policy (Q40/Q41): a policy raciocina sobre
  # `Current.user`. Autorização negada -> 403 (HTML e JSON) — user comum NÃO vê
  # nada do que a policy protege (ex.: /admin).
  authorize :user, through: :current_user
  rescue_from ActionPolicy::Unauthorized, with: :deny_access

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def deny_access
      respond_to do |format|
        format.html { render "shared/forbidden", status: :forbidden }
        format.json { render json: { error: "forbidden" }, status: :forbidden }
      end
    end
end
