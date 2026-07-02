require "test_helper"

# Status derivado da conta na listagem do admin (Q31) — SEM coluna nova:
#   suspenso  = suspended_at presente (tem prioridade)
#   convidado = nunca entrou (sessions.none?)
#   ativo     = já entrou ao menos uma vez
class UserStatusTest < ActiveSupport::TestCase
  test "convidado quando nunca entrou (sem sessão)" do
    user = create_user(email: "novo@example.com")
    assert_equal :invited, user.status
  end

  test "ativo quando já entrou (tem sessão)" do
    user = create_user(email: "ativo@example.com")
    user.sessions.create!
    assert_equal :active, user.status
  end

  test "suspenso tem prioridade mesmo tendo entrado antes" do
    keep_one_active_admin
    user = create_user(email: "susp@example.com")
    user.sessions.create!
    user.suspend!
    assert_equal :suspended, user.status
  end

  test "invited? é verdadeiro só pra quem nunca entrou" do
    user = create_user(email: "conv@example.com")
    assert user.invited?
    user.sessions.create!
    assert_not user.invited?
  end

  private
    def keep_one_active_admin
      User.create!(email: "admin@example.com", admin: true) unless User.exists?(admin: true)
    end
end
