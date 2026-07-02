module Admin
  # Página única do painel (Q68): a fila de pedidos pendentes no topo (só quando
  # há pendentes) + a tabela de contas + o form de convite. Carrega os dois
  # conjuntos que a view compartilhada renderiza.
  class DashboardController < BaseController
    def show
      @pending_requests = AccessRequest.pending.order(created_at: :asc)
      @users = User.order(:email)
    end
  end
end
