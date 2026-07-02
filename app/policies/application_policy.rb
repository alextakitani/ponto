# Base de autorização (Action Policy, Q40/Q41). A decisão canônica "pode/não pode"
# mora AQUI, não em before_action ad-hoc — controllers chamam authorize!.
#
# `user` é o contexto de autorização, resolvido de Current.user (ver
# ApplicationController#authorization_context). Ainda NÃO há relation_scope de
# tenant: as tabelas de domínio (Clients/Projects…) entram na fatia de domínio, e
# é lá que o escopo por user_id (isolamento Q23) ganha um relation_scope. Aqui a
# base fica enxuta de propósito.
class ApplicationPolicy < ActionPolicy::Base
  authorize :user

  private
    def admin?
      user&.admin?
    end
end
