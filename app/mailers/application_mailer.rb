class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "Ponto <from@example.com>")
  layout "mailer"

  # E-mail sai no idioma do DESTINATÁRIO (Q79 — app bilíngue): deliver_later roda
  # em job, onde I18n.locale é o default do processo — o locale do request que
  # disparou o e-mail não viaja junto. Todos os mailers recebem `user:` nos
  # params; nil (= "automático") cai no default pt-BR (e-mail não tem
  # Accept-Language pra consultar). Achado do review de i18n.
  around_action :switch_to_recipient_locale

  private
    def switch_to_recipient_locale(&block)
      locale = params && params[:user]&.locale.presence
      I18n.with_locale(locale || I18n.default_locale, &block)
    end
end
