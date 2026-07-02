require "test_helper"

# Deletar conta (Q33): apagar leva a BOLHA inteira, incluindo o domínio. Testamos
# que o cascade limpa auth + TimeEntries de uma vez.
class UserDestroyTest < ActiveSupport::TestCase
  test "destroy_completely apaga o user e toda a bolha de auth e entries" do
    keep_one_active_admin
    user = create_user(email: "vai@example.com")
    user.sessions.create!
    user.sign_in_codes.create!
    user.access_tokens.create!(permission: "read")
    user.time_entries.create!(started_at: Time.current - 1.hour, ended_at: Time.current)

    user.destroy_completely

    assert_not User.exists?(user.id)
    assert_equal 0, Session.where(user_id: user.id).count
    assert_equal 0, SignInCode.where(user_id: user.id).count
    assert_equal 0, AccessToken.where(user_id: user.id).count
    assert_equal 0, TimeEntry.where(user_id: user.id).count
  end

  # O último admin ativo é barrado pelo before_destroy (invariante Q34c), mesmo
  # pela porta do destroy_completely.
  test "destroy_completely respeita a invariante ≥1 admin ativo" do
    admin = create_user(email: "unico@example.com")
    admin.update!(admin: true)

    assert_not admin.destroy_completely
    assert User.exists?(admin.id)
  end

  private
    def keep_one_active_admin
      User.create!(email: "admin@example.com", admin: true) unless User.exists?(admin: true)
    end
end
