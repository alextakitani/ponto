# Concern único de auth (decisões §3, padrões clonados do fizzy):
#   1. cookie de sessão (humano no browser/PWA) — Session identificada por signed_id
#   2. Bearer AccessToken — só em requests JSON, escopado por método HTTP (extensão)
#   3. senão, exige login
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :current_user

    include Authentication::ViaSignInCode
  end

  class_methods do
    # Para páginas públicas (ex.: telas de login). Mantém current_user resolvido
    # se já houver sessão, mas não exige.
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      before_action :resume_session, **options
    end
  end

  private

  def authenticated?
    Current.user.present?
  end

  def current_user
    Current.user
  end

  def require_authentication
    resume_session || authenticate_by_bearer_token || request_authentication
  end

  # --- Cookie de sessão (signed_id) ------------------------------------------

  def resume_session
    if (session_record = find_session_by_cookie)
      set_current_session(session_record)
    end
  end

  def find_session_by_cookie
    Session.find_signed(cookies.signed[:session_token])
  end

  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session_record|
      set_current_session(session_record)
    end
  end

  def set_current_session(session_record)
    Current.session = session_record
    Current.user = session_record.user
    cookies.signed.permanent[:session_token] = {
      value: session_record.signed_id,
      httponly: true,
      same_site: :lax
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
    Current.session = nil
    Current.user = nil
  end

  # --- Bearer (extensão de Chrome) -------------------------------------------

  def authenticate_by_bearer_token
    return unless bearer_token_authenticatable_request?

    authenticate_with_http_token do |token|
      if (user = User.find_by_permissable_access_token(token, method: request.method))
        Current.user = user
      end
    end
  end

  def bearer_token_authenticatable_request?
    request.format.json? && request.authorization.to_s.include?("Bearer")
  end

  # --- Falha ------------------------------------------------------------------

  def request_authentication
    respond_to do |format|
      format.html do
        session[:return_to_after_authenticating] = request.url if request.get? || request.head?
        redirect_to sign_in_path, alert: "Faça login para continuar."
      end
      format.json { render json: { error: "unauthorized" }, status: :unauthorized }
    end
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end
end
