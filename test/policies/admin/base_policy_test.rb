require "test_helper"

# Lógica nossa: o painel de admin é CROSS-CONTA por design (Q32/Q25b) — NUNCA
# tenant-scoped. As policies de admin herdam de ApplicationPolicy (que tem o
# `relation_scope` de tenant `where(user:)`); se não sobrescreverem, o scope herdado
# vira `WHERE users.user = ?` (coluna inexistente) e ESTOURA no primeiro uso de
# `authorized_scope` em admin. Este teste trava esse override: aplicar scope em
# `User.all` NÃO filtra por tenant e devolve TODAS as contas.
class Admin::BasePolicyTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(email: "admin@example.com")
    @admin.update!(admin: true)
    @other = create_user(email: "other@example.com")
  end

  # Exercitamos via Admin::UserPolicy (subclasse concreta que roda sobre a tabela real
  # `users`) — é onde a herança bugada explodiria (WHERE users.user = ?).
  test "apply_scope em User.all NÃO filtra por tenant e devolve todas as contas" do
    scoped = nil

    assert_nothing_raised do
      scoped = Admin::UserPolicy
        .new(user: @admin)
        .apply_scope(User.all, type: :active_record_relation)
    end

    ids = scoped.pluck(:id)
    assert_includes ids, @admin.id
    assert_includes ids, @other.id, "admin deve enxergar contas de outros users (cross-conta)"
  end
end
