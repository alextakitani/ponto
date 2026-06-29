require "test_helper"

# Fluxo de login de duas etapas — controle de fluxo NOSSO (não framework):
# pending-token entre etapas, uso único do código, bearer escopado em JSON.
class SignInFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  test "página protegida sem sessão redireciona para o login" do
    get root_path
    assert_redirected_to sign_in_path
  end

  test "fluxo feliz: e-mail -> código -> sessão -> acessa página protegida" do
    code = request_code_for("alex@example.com")

    post sign_in_session_path, params: { code: code }
    assert_redirected_to root_path

    get root_path
    assert_response :success
  end

  test "a etapa do código exige o cookie de e-mail pendente" do
    # Sem passar pela etapa 1, não há token pendente.
    get verify_sign_in_path
    assert_redirected_to sign_in_path
  end

  test "uso único no HTTP: reenviar o mesmo código falha" do
    code = request_code_for("alex@example.com")
    post sign_in_session_path, params: { code: code }
    delete sign_out_path

    # Novo pending-token, mesmo código velho -> deve falhar.
    request_code_for("alex@example.com")
    post sign_in_session_path, params: { code: code }
    assert_response :unprocessable_entity
  end

  test "código errado não autentica" do
    request_code_for("alex@example.com")

    post sign_in_session_path, params: { code: "000000" }
    assert_response :unprocessable_entity
  end

  private

  # Faz a etapa 1 e devolve o código de 6 dígitos (capturado pelo mailer :test).
  # O envio é via deliver_later, então rodamos o job enfileirado.
  def request_code_for(email)
    perform_enqueued_jobs { post sign_in_path, params: { email: email } }
    ActionMailer::Base.deliveries.last.subject[/\d{6}/]
  end
end
