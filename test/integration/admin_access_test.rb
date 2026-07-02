require "test_helper"

# Autorização do painel de admin (Q40/Q41 — Action Policy). A decisão canônica
# "pode/não pode" mora em POLICY (authorize!), não em before_action ad-hoc.
#   - anônimo               -> cai no login (require_authentication vem antes)
#   - user comum autenticado -> 403 (a policy nega; NÃO vê nada de /admin)
#   - admin                  -> acessa
# Admin é CEGO pro domínio (Q25b): o painel só expõe User/AccessRequest.
class AdminAccessTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "anônimo é mandado pro login (não vaza a existência do /admin)" do
    get admin_root_path
    assert_redirected_to sign_in_path
  end

  test "user comum autenticado recebe 403 no painel" do
    sign_in_as("membro@example.com", keep_active_admin: true) # não-admin
    get admin_root_path
    assert_response :forbidden
  end

  test "admin acessa o painel" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)
    get admin_root_path
    assert_response :success
  end

  # Não-admin não consegue nem AGIR (não é só a view escondida): a mutação é
  # barrada pela policy antes de tocar o banco.
  test "user comum autenticado não consegue convidar (403, sem criar conta)" do
    sign_in_as("membro@example.com", keep_active_admin: true)

    assert_no_difference -> { User.count } do
      post admin_users_path, params: { user: { email: "invadido@example.com" } }
    end
    assert_response :forbidden
  end
end
