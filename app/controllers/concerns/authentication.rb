# Concern único de auth (decisões §3):
#   1. tenta cookie de sessão (humano no browser/PWA)
#   2. senão, Bearer AccessToken — só em requests JSON, escopado por método HTTP
#      (extensão de Chrome)
#   3. senão, exige login
#
# Resolve a dupla credencial num só lugar, evitando controllers separados.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :current_user, :signed_in?
  end

  class_methods do
    # Para páginas públicas (ex.: tela de login).
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  def current_user
    Current.user
  end

  def signed_in?
    current_user.present?
  end

  def require_authentication
    resume_session || authenticate_bearer || request_authentication
  end

  # --- Cookie de sessão -------------------------------------------------------

  def resume_session
    return unless (session_record = find_session_by_cookie)

    Current.session = session_record
    Current.user = session_record.user
  end

  def find_session_by_cookie
    token = cookies.signed[:session_token]
    Session.find_by(token: token) if token.present?
  end

  def start_new_session_for(user)
    session_record = Session.start_for(user, request)
    Current.session = session_record
    Current.user = user
    cookies.signed.permanent[:session_token] = {
      value: session_record.token,
      httponly: true,
      same_site: :lax
    }
    session_record
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
    Current.session = nil
    Current.user = nil
  end

  # --- Bearer (extensão de Chrome) -------------------------------------------

  def authenticate_bearer
    return unless request.format.json?

    token = bearer_token
    return unless token.present?

    access_token = AccessToken.find_by(token: token)
    return unless access_token&.allows?(request.request_method)

    access_token.touch_usage!
    Current.user = access_token.user
  end

  def bearer_token
    header = request.authorization.to_s
    header[/\ABearer (.+)\z/, 1]
  end

  # --- Falha ------------------------------------------------------------------

  def request_authentication
    respond_to do |format|
      format.html do
        session[:return_to] = request.fullpath if request.get? || request.head?
        redirect_to sign_in_path, alert: "Faça login para continuar."
      end
      format.json { render json: { error: "unauthorized" }, status: :unauthorized }
    end
  end

  def after_authentication_url
    session.delete(:return_to) || root_url
  end
end
