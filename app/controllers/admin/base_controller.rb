module Admin
  # Base dos controllers de admin (Q40/Q41). Um único authorize! aqui garante o
  # piso "tem que ser admin" em TODAS as ações do namespace — a policy é a fonte
  # da verdade (não before_action ad-hoc). Ações que precisam de regra mais fina
  # (ex.: não deletar A SI MESMO) chamam authorize! de novo no registro específico.
  #
  # Admin é CEGO pro domínio (Q25b): este namespace só toca User/AccessRequest,
  # NUNCA dados de domínio de outros usuários.
  class BaseController < ApplicationController
    # Todo o painel de admin vive dentro do shell do app (sidebar/nav), como as
    # demais áreas do logado. Sem isto o Rails cai no layout cru "application"
    # (sem sidebar) e o menu lateral some ao navegar pra /admin. O AhoyCaptain
    # não passa por aqui (é engine montada, com layout próprio).
    layout "app"

    before_action :authorize_admin_panel

    private
      def authorize_admin_panel
        authorize! with: Admin::BasePolicy
      end
  end
end
