module Admin
  module AccessRequests
    # Recusar um pedido como sub-resource REST (Q35): create resolve o pedido
    # (marca rejected, SILENCIOSO). A linha some da fila inline via Turbo Stream;
    # sem JS -> redirect pro painel.
    class RejectionsController < Admin::BaseController
      before_action :set_access_request

      def create
        @access_request.reject!

        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = t("admin.access_requests.rejections.created", email: @access_request.email) }
          format.html { redirect_to admin_root_path, notice: t("admin.access_requests.rejections.created", email: @access_request.email) }
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
