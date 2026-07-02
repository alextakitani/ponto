# Autorização do painel de admin (Q40/Q41). REGRA ÚNICA: admin gerencia CONTAS
# (User) e a fila de pedidos (AccessRequest) — e NADA MAIS. O admin é CEGO pro
# domínio (Q25b): NUNCA vê nem toca dados de domínio alheios (Clients/Projects/
# TimeEntries…). Por isso as policies de admin herdam daqui e o padrão é: toda
# ação exige `admin?`, ponto. Se algum dia uma policy de admin precisar de regra
# mais fina, ela refina — mas o piso é sempre "tem que ser admin".
class Admin::BasePolicy < ApplicationPolicy
  # Sobrescreve o `relation_scope` de tenant herdado da ApplicationPolicy
  # (`where(user:)`): admin é OPERACIONAL e cross-conta por design (Q32/Q25b) —
  # NUNCA tenant-scoped. Sem este override, `authorized_scope User.all` viraria
  # `WHERE users.user = ?` (coluna inexistente) e estouraria. Devolvemos a relação
  # intacta. O escopo de dados de DOMÍNIO continua PROIBIDO por outra via: não
  # existe rota nem policy de domínio no namespace admin (o painel só toca User e
  # AccessRequest), então o admin nunca alcança Clients/Projects/TimeEntries alheios.
  relation_scope { |relation| relation }

  # `default_rule` cobre regras SEM método próprio. Mas o Action Policy já define
  # as regras CRUD (create?/update?/destroy?…) devolvendo false por padrão — elas
  # NÃO caem no default_rule. Por isso aliasamos todas explicitamente pra manage?:
  # o piso do painel é "tem que ser admin", pra QUALQUER verbo.
  default_rule :manage?
  alias_rule :index?, :show?, :new?, :create?, :edit?, :update?, :destroy?, to: :manage?

  def manage?
    admin?
  end
end
