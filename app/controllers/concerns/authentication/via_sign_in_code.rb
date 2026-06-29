# Estado entre as duas etapas do login (decisões §3, padrão fizzy ViaMagicLink):
# o e-mail "pendente de autenticação" viaja num cookie ASSINADO (não na URL),
# à prova de adulteração e com expiração. Em dev o código é servido via flash +
# header X-Sign-In-Code, com guarda que impede vazamento fora de dev.
module Authentication::ViaSignInCode
  extend ActiveSupport::Concern

  included do
    after_action :ensure_development_code_not_leaked
  end

  private

  # Inicia a etapa 2: guarda o e-mail no cookie assinado e (em dev) serve o código.
  def begin_sign_in_code_authentication(sign_in_code)
    serve_development_code(sign_in_code)
    set_pending_authentication_token(sign_in_code.user.email, expires_at: sign_in_code.expires_at)
  end

  def email_pending_authentication
    pending_authentication_token_verifier.verified(cookies[:pending_authentication_token])
  end

  def set_pending_authentication_token(email, expires_at:)
    cookies[:pending_authentication_token] = {
      value: pending_authentication_token_verifier.generate(email, expires_at: expires_at),
      httponly: true,
      same_site: :lax,
      expires: expires_at
    }
  end

  def clear_pending_authentication_token
    cookies.delete(:pending_authentication_token)
  end

  def pending_authentication_token_verifier
    Rails.application.message_verifier(:pending_authentication)
  end

  # --- Código em dev ----------------------------------------------------------

  def serve_development_code(sign_in_code)
    if Rails.env.development? && sign_in_code.code.present?
      flash[:sign_in_code] = sign_in_code.code
      response.set_header("X-Sign-In-Code", sign_in_code.code)
    end
  end

  def ensure_development_code_not_leaked
    unless Rails.env.development?
      raise "Vazando código de login via flash em #{Rails.env}?" if flash[:sign_in_code].present?
    end
  end
end
