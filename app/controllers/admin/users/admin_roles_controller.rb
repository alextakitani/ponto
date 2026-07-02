module Admin
  module Users
    # Papel de admin como sub-resource REST (Q34): create promove, destroy rebaixa.
    # A invariante ≥1 admin ativo mora na validação do model (rebaixar o último
    # admin ativo falha no update) — aqui reembrulhamos num alert amigável.
    class AdminRolesController < Admin::BaseController
      before_action :set_user

      def create
        if @user.update(admin: true)
          redirect_to admin_root_path, notice: "#{@user.email} agora é admin."
        else
          redirect_to admin_root_path, alert: @user.errors.full_messages.to_sentence
        end
      end

      def destroy
        if @user.update(admin: false)
          redirect_to admin_root_path, notice: "#{@user.email} não é mais admin."
        else
          redirect_to admin_root_path, alert: @user.errors.full_messages.to_sentence
        end
      end

      private
        def set_user
          @user = User.find(params[:user_id])
        end
    end
  end
end
