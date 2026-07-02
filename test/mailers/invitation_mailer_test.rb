require "test_helper"

# Convite informativo (Pull, Q24/Task 1.4): avisa que a conta foi criada e manda
# entrar. NÃO carrega código/segredo — o magic-code nasce quando a pessoa logar.
class InvitationMailerTest < ActiveSupport::TestCase
  test "o convite tem o link de entrar e NÃO carrega código de 6 dígitos" do
    user = User.create!(email: "convidado@example.com")

    mail = InvitationMailer.with(user: user).created
    sign_in_url = Rails.application.routes.url_helpers.sign_in_url(host: "example.com")

    assert_equal [ "convidado@example.com" ], mail.to
    assert_match sign_in_url, mail.body.encoded
    assert_no_match(/\b\d{6}\b/, mail.body.encoded)
  end
end
