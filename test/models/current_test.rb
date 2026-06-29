require "test_helper"

# Lógica nossa: setar a sessão resolve o usuário em cascata.
class CurrentTest < ActiveSupport::TestCase
  test "atribuir Current.session resolve Current.user" do
    user = create_user
    session = user.sessions.create!

    Current.session = session
    assert_equal user, Current.user
  end

  test "zerar Current.session zera Current.user" do
    user = create_user
    Current.session = user.sessions.create!

    Current.session = nil
    assert_nil Current.user
  end
end
