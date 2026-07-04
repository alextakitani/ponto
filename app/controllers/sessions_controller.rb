# Login passwordless de duas etapas na mesma aba (decisões §3):
#   new            -> form de e-mail
#   create         -> emite código, guarda e-mail no cookie assinado, troca o form
#   verify         -> form de código (exige cookie de e-mail pendente)
#   create_session -> consome código + confere e-mail (secure_compare) + abre sessão
#   destroy        -> logout
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create verify create_session]
  # Um user suspenso ainda precisa conseguir SAIR (o gate barraria o logout,
  # travando o botão "Sair" da própria página de conta suspensa — Q34).
  allow_suspended_access only: :destroy
  before_action :ensure_email_pending, only: %i[verify create_session]

  # Rate limit no envio é a defesa principal do esquema (decisões §3).
  rate_limit to: 5, within: 1.minute, only: :create, with: :rate_limit_exceeded

  def new
  end

  def create
    email = User.normalize_value_for(:email, params[:email])
    # Convite-only (Q28): entrar NÃO cria conta. Único caso que cria é o bootstrap
    # do 1º admin via ADMIN_EMAIL (Q37), quando o banco ainda está vazio.
    user = User.find_by(email: email) || User.bootstrap_admin(email)

    if user
      begin_sign_in_code_authentication(user.send_sign_in_code)

      respond_to do |format|
        format.turbo_stream # troca o form de e-mail pelo de código
        format.html { redirect_to verify_sign_in_path }
      end
    else
      # Resposta explícita por decisão de design (sem enumeração-paranoia).
      # Chave dedicada (account_missing) só aqui: é o único alert que puxa o link
      # "pedir acesso" na view. Alerts genéricos (login exigido, rate limit) usam
      # flash[:alert] cru e NÃO ganham o link.
      # TODO(Task 1.3): trocar o alvo do link pela landing com o form de acesso.
      flash.now[:account_missing] = true
      flash.now[:alert] = t("sessions.create.account_missing")
      render :new, status: :unprocessable_entity
    end
  end

  def verify
  end

  def create_session
    user = User.find_by(email: email_pending_authentication)

    if user && (code = SignInCode.consume(user, params[:code])) && emails_match?(user)
      clear_pending_authentication_token
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: t("sessions.create.welcome")
    else
      flash.now[:alert] = t("sessions.create.invalid_code")
      render :verify, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to sign_in_path, notice: t("sessions.destroy.signed_out")
  end

  private

  def ensure_email_pending
    return if email_pending_authentication.present?

    redirect_to sign_in_path, alert: t("sessions.verify.email_required")
  end

  # Disponível pro before_action e pras views (mostra o e-mail pendente).
  helper_method :email_pending_authentication
  def email_pending_authentication
    @email_pending_authentication ||= super
  end

  def emails_match?(user)
    ActiveSupport::SecurityUtils.secure_compare(
      email_pending_authentication.to_s, user.email.to_s
    )
  end

  def rate_limit_exceeded
    redirect_to sign_in_path, alert: t("sessions.rate_limited")
  end
end
