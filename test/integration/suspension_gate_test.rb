require "test_helper"

# Gate de suspensão (Q34): depois de resolver o user (sessão OU bearer), antes de
# liberar, user suspenso é barrado a CADA request. HTML -> redirect pra página
# "conta suspensa"; JSON -> 403. A sessão NÃO é destruída (reativar restaura).
class SuspensionGateTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  # --- HTML: sessão de cookie -------------------------------------------------

  test "user suspenso (sessão HTML) é redirecionado pra página de conta suspensa" do
    user = sign_in_as("membro@example.com")
    suspend(user)

    get root_path
    assert_redirected_to suspended_path
  end

  test "user NÃO suspenso passa normalmente" do
    sign_in_as("membro@example.com")

    get root_path
    assert_response :success
  end

  test "a própria página de conta suspensa é acessível mesmo suspenso (sem loop)" do
    user = sign_in_as("membro@example.com")
    suspend(user)

    get suspended_path
    assert_response :success
  end

  test "reativar restaura o acesso sem novo login (sessão sobrevive)" do
    user = sign_in_as("membro@example.com")
    suspend(user)
    get root_path
    assert_redirected_to suspended_path

    user.reactivate!
    get root_path
    assert_response :success
  end

  test "user suspenso ainda consegue sair (logout não é barrado pelo gate)" do
    user = sign_in_as("membro@example.com")
    suspend(user)

    delete sign_out_path
    assert_redirected_to sign_in_path # deslogou de fato, não caiu em /suspended
  end

  # --- JSON: bearer -----------------------------------------------------------

  test "user suspenso (bearer JSON) recebe 403 com erro" do
    user = create_user(email: "ext@example.com")
    keep_one_active_admin
    token = user.access_tokens.create!(permission: "read")
    user.suspend!

    get root_path, headers: { "Authorization" => "Bearer #{token.token}" }, as: :json
    assert_response :forbidden
    assert_match(/conta suspensa/, response.parsed_body["error"].to_s)
  end

  private

  # Cria o user e estabelece a sessão de cookie pelo fluxo real de login.
  def sign_in_as(email)
    user = create_user(email: email)
    keep_one_active_admin
    perform_enqueued_jobs { post sign_in_path, params: { email: email } }
    code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
    post sign_in_session_path, params: { code: code }
    user
  end

  # Suspender exige outro admin ativo (invariante Q34c) — garantimos um.
  def suspend(user)
    keep_one_active_admin
    user.suspend!
  end

  def keep_one_active_admin
    User.create!(email: "admin@example.com", admin: true) unless User.exists?(admin: true)
  end
end
