module Admin
  # Página única do painel (Q68): a fila de pedidos pendentes no topo (só quando
  # há pendentes) + a tabela de contas + o form de convite. Carrega os dois
  # conjuntos que a view compartilhada renderiza.
  class DashboardController < BaseController
    def show
      @pending_requests = AccessRequest.pending.order(created_at: :asc)
      # Traz o COUNT de sessions de cada conta numa query só (evita o N+1 do
      # invited?/status por linha da tabela). O `with_sessions_count` expõe a
      # coluna virtual sessions_count, que o User#invited? aproveita.
      @users = User.with_sessions_count.order(:email)
    end
  end
end
