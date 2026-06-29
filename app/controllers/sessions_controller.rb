# Login passwordless de duas etapas na mesma aba (decisões §3):
#   new      -> form de e-mail
#   create   -> emite código de 6 dígitos, manda por e-mail, troca o form (Turbo Stream)
#   verify   -> consome código e abre sessão
#   destroy  -> logout
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create verify create_session]

  # Rate limit no envio de código é a defesa principal do esquema. Decisões §3.
  rate_limit to: 5, within: 1.minute, only: :create,
             with: -> { redirect_to sign_in_path, alert: "Muitas tentativas. Aguarde um minuto." }

  def new
  end

  def create
    @user = User.find_or_create_by(email: User.normalize_value_for(:email, params[:email]))

    if @user.persisted?
      code = @user.issue_sign_in_code
      SignInMailer.with(user: @user, code: code).code.deliver_later

      respond_to do |format|
        format.turbo_stream # substitui o form de e-mail pelo de código
        format.html { redirect_to verify_sign_in_path(email: @user.email) }
      end
    else
      flash.now[:alert] = "E-mail inválido."
      render :new, status: :unprocessable_entity
    end
  end

  # GET para fallback non-Turbo (recebeu no celular, abriu no desktop).
  def verify
    @email = params[:email]
    render :verify
  end

  def create_session
    user = User.find_by(email: User.normalize_value_for(:email, params[:email]))
    record = user&.sign_in_codes&.active&.order(created_at: :desc)&.find do |c|
      c.code_digest == User.digest_code(params[:code].to_s.strip)
    end

    if record&.consume!
      start_new_session_for(record.user)
      redirect_to after_authentication_url, notice: "Bem-vindo!"
    else
      @email = params[:email]
      flash.now[:alert] = "Código inválido ou expirado."
      render :verify, status: :unprocessable_entity
    end
  end

  def destroy
    terminate_session
    redirect_to sign_in_path, notice: "Você saiu."
  end
end
