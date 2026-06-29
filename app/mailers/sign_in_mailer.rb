class SignInMailer < ApplicationMailer
  # Recebe o código em claro como argumento — ver User#send_sign_in_code.
  def code
    @user = params[:user]
    @code = params[:code]
    mail to: @user.email, subject: "Seu código de acesso ao Ponto: #{@code}"
  end
end
