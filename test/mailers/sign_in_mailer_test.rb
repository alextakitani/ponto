require "test_helper"

# Regressão: o código em claro precisa sobreviver ao deliver_later (que serializa
# e recarrega o record, perdendo atributos transientes). O e-mail deve conter o
# código de 6 dígitos no assunto e no corpo.
class SignInMailerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "o e-mail entregue carrega o código de 6 dígitos" do
    user = User.create!(email: "alex@example.com")

    perform_enqueued_jobs { user.send_sign_in_code }
    mail = ActionMailer::Base.deliveries.last

    assert_equal [ "alex@example.com" ], mail.to
    assert_match(/\d{6}/, mail.subject)
    assert_match(/\d{6}/, mail.body.encoded)
  end

  # Regressão (review i18n): deliver_later roda em job com o locale default —
  # o idioma do e-mail deve vir da PREFERÊNCIA do destinatário, não do processo.
  test "o e-mail sai no idioma do destinatário" do
    user = User.create!(email: "en@example.com", locale: "en")

    perform_enqueued_jobs { user.send_sign_in_code }
    mail = ActionMailer::Base.deliveries.last

    code = mail.subject[/\d{6}/]
    assert_equal I18n.t("sign_in_mailer.code.subject", code: code, locale: :en), mail.subject
  end
end
