# Concern único de auth (decisões §3, padrões clonados do fizzy):
#   1. cookie de sessão (humano no browser/PWA) — Session identificada por signed_id
#   2. Bearer AccessToken — requests JSON/export, escopado por método HTTP (extensão)
#   3. senão, exige login
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
    before_action :require_authentication
    # Gate de suspensão (Q34): roda DEPOIS de resolver o user, a cada request.
    before_action :require_active_account
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

    # Isenta do gate de suspensão (Q34): a própria página "conta suspensa" e a
    # futura rota de export usam isso — senão o redirect entraria em loop.
    def allow_suspended_access(**options)
      skip_before_action :require_active_account, **options
    end
  end

  private

  def authenticated?
    Current.user.present?
  end

  def current_user
    Current.user
  end

  def set_current_request_details
    Current.request_id = request.uuid
    Current.user_agent = request.user_agent
    Current.ip_address = request.remote_ip
  end

  def require_authentication
    resume_session || authenticate_by_bearer_token || request_authentication
  end

  # Barra o user suspenso a cada request (Q34). NÃO destrói a sessão: reativar
  # restaura o acesso no request seguinte, sem novo login.
  def require_active_account
    return unless Current.user&.suspended?

    respond_to do |format|
      format.html { redirect_to suspended_path }
      format.json { render json: { error: I18n.t("auth.errors.suspended") }, status: :forbidden }
      format.any(:csv, :xlsx) { render plain: I18n.t("auth.errors.suspended"), status: :forbidden }
    end
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
    Current.session = session_record # resolve Current.user em cascata
    cookies.signed.permanent[:session_token] = {
      value: session_record.signed_id,
      httponly: true,
      same_site: :lax
    }
  end

  def terminate_session
    Current.session&.destroy
    cookies.delete(:session_token)
    Current.session = nil # zera Current.user em cascata
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
    bearer_request_format? && request.authorization.to_s.include?("Bearer")
  end

  def bearer_request_format?
    # Export é o entregável principal; CLI/cron baixam via token Bearer.
    request.format.json? || request.format.csv? || request.format.xlsx?
  end

  # --- Falha ------------------------------------------------------------------

  def request_authentication
    respond_to do |format|
      format.html do
        session[:return_to_after_authenticating] = request.url if request.get? || request.head?
        redirect_to sign_in_path, alert: t("auth.errors.sign_in_required")
      end
      format.json { render json: { error: t("auth.errors.unauthorized") }, status: :unauthorized }
      format.any(:csv, :xlsx) do
        if request.authorization.to_s.include?("Bearer")
          render plain: t("auth.errors.unauthorized"), status: :unauthorized
        else
          head :not_acceptable
        end
      end
    end
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end
end
