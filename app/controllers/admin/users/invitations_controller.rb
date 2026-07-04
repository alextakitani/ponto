module Admin
  module Users
    # Reenviar convite como sub-resource REST (Q31): create re-dispara o mesmo
    # InvitationMailer.created. Só faz sentido pra quem NUNCA entrou (convidado,
    # sessions.none?); pra quem já entrou é no-op explícito com aviso.
    class InvitationsController < Admin::BaseController
      before_action :set_user

      def create
        if @user.invited?
          InvitationMailer.with(user: @user).created.deliver_later
          redirect_to admin_root_path, notice: t("admin.users.invitations.created", email: @user.email)
        else
          redirect_to admin_root_path, alert: t("admin.users.invitations.already_joined", email: @user.email)
        end
      end

      private
        def set_user
          @user = User.find(params[:user_id])
        end
    end
  end
end
