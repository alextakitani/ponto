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
    sign_in_as("membro@example.com") # não-admin
    get admin_root_path
    assert_response :forbidden
  end

  test "admin acessa o painel" do
    sign_in_as("chefe@example.com", admin: true)
    get admin_root_path
    assert_response :success
  end

  # Não-admin não consegue nem AGIR (não é só a view escondida): a mutação é
  # barrada pela policy antes de tocar o banco.
  test "user comum autenticado não consegue convidar (403, sem criar conta)" do
    sign_in_as("membro@example.com")

    assert_no_difference -> { User.count } do
      post admin_users_path, params: { user: { email: "invadido@example.com" } }
    end
    assert_response :forbidden
  end

  private
    # Cria o user e estabelece a sessão de cookie pelo fluxo real de login.
    def sign_in_as(email, admin: false)
      user = User.create!(email: email, admin: admin)
      keep_one_active_admin
      perform_enqueued_jobs { post sign_in_path, params: { email: email } }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post sign_in_session_path, params: { code: code }
      user
    end

    def keep_one_active_admin
      User.create!(email: "outro-admin@example.com", admin: true) unless User.exists?(admin: true)
    end
end
