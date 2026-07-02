require "test_helper"

# Lógica nossa: resolução de usuário por AccessToken, respeitando o escopo.
class UserTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "find_by_permissable_access_token devolve o usuário quando o método é permitido" do
    token = @user.access_tokens.create!(permission: "write")

    assert_equal @user, User.find_by_permissable_access_token(token.token, method: "POST")
  end

  test "devolve nil quando o método está fora do escopo do token" do
    token = @user.access_tokens.create!(permission: "read")

    assert_nil User.find_by_permissable_access_token(token.token, method: "POST")
  end

  test "devolve nil para token inexistente" do
    assert_nil User.find_by_permissable_access_token("nao-existe", method: "GET")
  end

  test "registra last_used_at quando o acesso é permitido" do
    token = @user.access_tokens.create!(permission: "read")
    assert_nil token.last_used_at

    User.find_by_permissable_access_token(token.token, method: "GET")
    assert token.reload.last_used_at.present?
  end

  test "não registra uso quando o acesso é negado pelo escopo" do
    token = @user.access_tokens.create!(permission: "read")

    User.find_by_permissable_access_token(token.token, method: "DELETE")
    assert_nil token.reload.last_used_at
  end

  # --- Suspensão (Q34): estado por timestamp (soft-state do projeto) -----------

  test "suspended? reflete a presença de suspended_at" do
    admin = create_user(email: "admin@example.com")
    admin.update!(admin: true) # garante que sobra outro admin ativo (invariante Q34c)
    user = create_user(email: "membro@example.com")

    assert_not user.suspended?
    user.suspend!
    assert user.suspended?
    user.reactivate!
    assert_not user.suspended?
  end

  # --- Invariante ≥1 admin ATIVO (Q34c) ---------------------------------------

  test "suspender o último admin ativo levanta LastAdminError" do
    admin = create_user(email: "so@example.com")
    admin.update!(admin: true)

    assert_raises(User::LastAdminError) { admin.suspend! }
    assert_not admin.reload.suspended?
  end

  # update cru de suspended_at (sem passar pelo suspend!) também é barrado pela
  # validação — senão o eixo suspensão fura a invariante ≥1 admin ativo.
  test "update cru de suspended_at no último admin ativo é barrado pela validação" do
    admin = create_user(email: "so@example.com")
    admin.update!(admin: true)

    assert_not admin.update(suspended_at: Time.current)
    assert_not admin.reload.suspended?
  end

  test "rebaixar o último admin ativo falha na validação" do
    admin = create_user(email: "so@example.com")
    admin.update!(admin: true)

    assert_not admin.update(admin: false)
    assert admin.reload.admin?
  end

  test "destruir o último admin ativo é abortado" do
    admin = create_user(email: "so@example.com")
    admin.update!(admin: true)

    assert_not admin.destroy
    assert User.exists?(admin.id)
  end

  # Caso feliz: com 2 admins ativos, mexer em um funciona.
  test "com dois admins ativos, suspender/rebaixar/destruir um funciona" do
    keep = create_user(email: "fica@example.com")
    keep.update!(admin: true)
    other = create_user(email: "outro@example.com")
    other.update!(admin: true)

    assert other.suspend!
    other.reactivate!
    assert other.update(admin: false)
    other.update!(admin: true)
    assert other.destroy
  end

  # Um admin ATIVO + um admin SUSPENSO: o suspenso não conta como "ativo".
  test "admin suspenso não conta como admin ativo para a invariante" do
    active = create_user(email: "ativo@example.com")
    active.update!(admin: true)
    suspended = create_user(email: "susp@example.com")
    suspended.update!(admin: true)
    suspended.suspend!

    # active é o ÚNICO admin ativo -> não pode ser suspenso/rebaixado/destruído.
    assert_raises(User::LastAdminError) { active.suspend! }
    assert_not active.update(admin: false)
    assert_not active.destroy
  end
end
