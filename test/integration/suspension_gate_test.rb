require "test_helper"

# Gate de suspensão (Q34): depois de resolver o user (sessão OU bearer), antes de
# liberar, user suspenso é barrado a CADA request. HTML -> redirect pra página
# "conta suspensa"; JSON -> 403. A sessão NÃO é destruída (reativar restaura).
#
# Batemos em home_path (não root_path): a raiz virou a landing pública (Q36), que
# é allow_unauthenticated_access e portanto pula o gate. A home protegida (/home)
# é que exercita auth + suspensão.
class SuspensionGateTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  # --- HTML: sessão de cookie -------------------------------------------------

  test "user suspenso (sessão HTML) é redirecionado pra página de conta suspensa" do
    user = sign_in_as("membro@example.com", keep_active_admin: true)
    suspend(user)

    get home_path
    assert_redirected_to suspended_path
  end

  test "user NÃO suspenso passa normalmente" do
    sign_in_as("membro@example.com", keep_active_admin: true)

    get home_path
    assert_response :success
  end

  test "a própria página de conta suspensa é acessível mesmo suspenso (sem loop)" do
    user = sign_in_as("membro@example.com", keep_active_admin: true)
    suspend(user)

    get suspended_path
    assert_response :success
  end

  test "reativar restaura o acesso sem novo login (sessão sobrevive)" do
    user = sign_in_as("membro@example.com", keep_active_admin: true)
    suspend(user)
    get home_path
    assert_redirected_to suspended_path

    user.reactivate!
    get home_path
    assert_response :success
  end

  test "user suspenso ainda consegue sair (logout não é barrado pelo gate)" do
    user = sign_in_as("membro@example.com", keep_active_admin: true)
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

    get home_path, headers: { "Authorization" => "Bearer #{token.token}" }, as: :json
    assert_response :forbidden
    assert_match(/conta suspensa/, response.parsed_body["error"].to_s)
  end

  private

  # Suspender exige outro admin ativo (invariante Q34c) — garantimos um.
  def suspend(user)
    keep_one_active_admin
    user.suspend!
  end

  def keep_one_active_admin
    User.create!(email: "admin@example.com", admin: true) unless User.exists?(admin: true)
  end
end
