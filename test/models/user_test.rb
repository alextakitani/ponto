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
end
