module Clients
  # Arquivamento de cliente como sub-resource REST (Q7): create arquiva, destroy
  # desarquiva. Espelha o Admin::Users::SuspensionsController — ação sem verbo padrão
  # vira sub-resource, não custom action (STYLE.md). A soft-delete em si mora no
  # concern Archivable (archive!/unarchive!); aqui só embrulhamos no fluxo do controller.
  class ArchivalsController < ApplicationController
    before_action :set_client

    def create
      @client.archive!
      redirect_to clients_path, notice: t("clients.archivals.created")
    end

    def destroy
      @client.unarchive!
      redirect_to clients_path(archived: "1"), notice: t("clients.archivals.destroyed")
    end

    private
      def set_client
        # Escopado pra bolha do user (Q23): cliente alheio não está no escopo → 404.
        @client = authorized_scope(Client.all).find(params[:client_id])
      end
  end
end
