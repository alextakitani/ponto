require "test_helper"

# Lógica nossa: mapeamento permission (read/write) -> método HTTP permitido.
class AccessTokenTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "token read libera só leitura (GET/HEAD)" do
    token = @user.access_tokens.create!(permission: "read")

    assert token.allows?(:get)
    assert token.allows?("HEAD")
    assert_not token.allows?(:post)
    assert_not token.allows?("DELETE")
    assert_not token.allows?(:patch)
  end

  test "token write libera leitura e escrita" do
    token = @user.access_tokens.create!(permission: "write")

    assert token.allows?(:get)
    assert token.allows?(:post)
    assert token.allows?("DELETE")
  end

  test "allows? é case-insensitive no método" do
    token = @user.access_tokens.create!(permission: "read")

    assert token.allows?("get")
    assert token.allows?("Get")
  end
end
