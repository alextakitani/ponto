module Admin
  module AccessRequests
    # Aprovar um pedido como sub-resource REST (Q35): create resolve o pedido
    # (cria a conta + dispara o convite). A linha some da fila inline via Turbo
    # Stream; sem JS -> redirect pro painel.
    class ApprovalsController < Admin::BaseController
      before_action :set_access_request

      def create
        @access_request.approve!

        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = t("admin.access_requests.approvals.created", email: @access_request.email) }
          format.html { redirect_to admin_root_path, notice: t("admin.access_requests.approvals.created", email: @access_request.email) }
        end
      rescue AccessRequest::InvalidTransition => e
        redirect_to admin_root_path, alert: e.message
      end

      private
        def set_access_request
          @access_request = AccessRequest.find(params[:access_request_id])
        end
    end
  end
end
