module Admin
  # Contas (Q29/Q33). create = convidar (cria User + dispara o convite Pull);
  # destroy = deletar a bolha inteira, com proteções (Q33).
  class UsersController < BaseController
    before_action :set_user, only: :destroy

    # Convidar (Q29/Q30/Q32): cria a conta e dispara o InvitationMailer.created.
    # E-mail duplicado é barrado pela unicidade do User -> erro amigável no form.
    def create
      user = User.new(user_params)

      if user.save
        InvitationMailer.with(user: user).created.deliver_later
        redirect_to admin_root_path, notice: t("admin.users.create.invited", email: user.email)
      else
        redirect_to admin_root_path, alert: user.errors.full_messages.to_sentence
      end
    end

    # Deletar (Q33): confirmação por digitação do E-MAIL do alvo. E-mail errado ->
    # recusa. Não pode deletar A SI MESMO (policy). Último admin ativo -> barrado
    # pelo model (destroy_completely devolve false). Cascade leva a bolha inteira.
    def destroy
      authorize! @user, to: :destroy?, with: Admin::UserPolicy

      if confirmation_matches?
        if @user.destroy_completely
          redirect_to admin_root_path, notice: t("admin.users.destroy.removed", email: @user.email)
        else
          redirect_to admin_root_path, alert: @user.errors.full_messages.to_sentence
        end
      else
        redirect_to admin_root_path, alert: t("admin.users.destroy.confirmation_mismatch")
      end
    end

    private
      def set_user
        @user = User.find(params[:id])
      end

      def user_params
        params.require(:user).permit(:email, :name)
      end

      # Guard-rail contra deleção acidental (Q33): o form manda o e-mail digitado.
      # Comparação normalizada (não secure_compare): o e-mail do alvo já aparece na
      # própria tela, então timing não é ameaça aqui — e o e-mail do User já vem
      # normalizado (strip/downcase). Bônus: aceita variação de caixa/espaço.
      def confirmation_matches?
        params[:email_confirmation].to_s.strip.downcase == @user.email
      end
  end
end
