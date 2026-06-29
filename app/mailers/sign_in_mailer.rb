class SignInMailer < ApplicationMailer
  def code
    @user = params[:user]
    @code = params[:code]
    mail to: @user.email, subject: "Seu código de acesso ao Ponto: #{@code}"
  end
end
