class SignInMailer < ApplicationMailer
  def code
    @sign_in_code = params[:sign_in_code]
    @user = @sign_in_code.user
    @code = @sign_in_code.code
    mail to: @user.email, subject: "Seu código de acesso ao Ponto: #{@code}"
  end
end
