class InvitationMailer < ApplicationMailer
  # Convite informativo (Q24): avisa que a conta foi criada e manda a pessoa
  # entrar. NÃO carrega código/segredo — o magic-code de 6 dígitos nasce quando
  # ela pedir pra entrar (SignInMailer). O disparo vem na Task 1.4.
  def created
    @user = params[:user]
    mail to: @user.email, subject: t(".subject")
  end
end
