# Autorização do painel de admin (Q40/Q41). REGRA ÚNICA: admin gerencia CONTAS
# (User) e a fila de pedidos (AccessRequest) — e NADA MAIS. O admin é CEGO pro
# domínio (Q25b): NUNCA vê nem toca dados de domínio alheios (Clients/Projects/
# TimeEntries…). Por isso as policies de admin herdam daqui e o padrão é: toda
# ação exige `admin?`, ponto. Se algum dia uma policy de admin precisar de regra
# mais fina, ela refina — mas o piso é sempre "tem que ser admin".
class Admin::BasePolicy < ApplicationPolicy
  # `default_rule` cobre regras SEM método próprio. Mas o Action Policy já define
  # as regras CRUD (create?/update?/destroy?…) devolvendo false por padrão — elas
  # NÃO caem no default_rule. Por isso aliasamos todas explicitamente pra manage?:
  # o piso do painel é "tem que ser admin", pra QUALQUER verbo.
  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, :manage?, to: :manage?

  def manage?
    admin?
  end
end
