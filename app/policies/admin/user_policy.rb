# Autorização das ações de admin sobre CONTAS (Q29/Q33/Q34). Herda o piso "tem que
# ser admin" da base; a única regra fina é NÃO deixar o admin se auto-deletar (Q33):
# a proteção do último-admin já mora no model, mas "não deletar A SI MESMO" é regra
# de autorização e vive aqui.
class Admin::UserPolicy < Admin::BasePolicy
  def destroy?
    admin? && record != user
  end
end
