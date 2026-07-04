class SignInMailer < ApplicationMailer
  # Recebe o código em claro como argumento — ver User#send_sign_in_code.
  def code
    @user = params[:user]
    @code = params[:code]
    mail to: @user.email, subject: t(".subject", code: @code)
  end
end
