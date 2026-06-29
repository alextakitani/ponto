# Dev/test: como não há SMTP real, registramos o código de login no log para
# facilitar o teste manual. Ver decisões §3 (entrega do código por e-mail) e a
# escolha de "ActionMailer + log". Em produção use um delivery_method real e
# este interceptor fica inativo.
if Rails.env.local?
  class SignInCodeLogger
    def self.delivering_email(message)
      Rails.logger.info "[Ponto] E-mail de login para #{message.to&.join(', ')} — #{message.subject}"
    end
  end

  ActionMailer::Base.register_interceptor(SignInCodeLogger)
end
