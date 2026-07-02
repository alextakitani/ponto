module Admin
  module Users
    # Suspensão de conta como sub-resource REST (Q34): create suspende, destroy
    # reativa. A invariante ≥1 admin ativo mora no model (suspend! levanta
    # LastAdminError) — aqui só reembrulhamos num alert amigável.
    class SuspensionsController < Admin::BaseController
      before_action :set_user

      def create
        @user.suspend!
        redirect_to admin_root_path, notice: "Conta de #{@user.email} suspensa."
      rescue User::LastAdminError => e
        redirect_to admin_root_path, alert: e.message
      end

      def destroy
        @user.reactivate!
        redirect_to admin_root_path, notice: "Conta de #{@user.email} reativada."
      end

      private
        def set_user
          @user = User.find(params[:user_id])
        end
    end
  end
end
