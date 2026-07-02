require "test_helper"

# Login é convite-only (Q28/Q37/Q38): entrar NÃO cria conta. Exceções controladas:
# bootstrap do 1º admin via ADMIN_EMAIL, e aviso de operador quando não há conta
# nem ADMIN_EMAIL. Testamos o controle de fluxo NOSSO, não o framework.
#
# ⚠️ Paralelização: estes testes mutam ENV["ADMIN_EMAIL"] e dependem de User.none?
# (banco vazio). Isso é seguro no modo default do Rails (parallelize por PROCESSOS:
# cada worker é um fork com ENV e DB próprios). QUEBRARIA com
# parallelize(with: :threads), onde os workers compartilham ENV e a mesma conexão.
class InviteOnlySignInTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @admin_email_backup = ENV["ADMIN_EMAIL"]
  end

  teardown do
    if @admin_email_backup.nil?
      ENV.delete("ADMIN_EMAIL")
    else
      ENV["ADMIN_EMAIL"] = @admin_email_backup
    end
  end

  # --- B: login não cria conta ------------------------------------------------

  test "e-mail desconhecido NÃO cria User" do
    create_user(email: "conhecido@example.com") # garante que o banco não está vazio
    ENV.delete("ADMIN_EMAIL")

    assert_no_difference -> { User.count } do
      post sign_in_path, params: { email: "desconhecido@example.com" }
    end
  end

  test "e-mail desconhecido re-renderiza o form com mensagem explícita e link" do
    create_user(email: "conhecido@example.com")
    ENV.delete("ADMIN_EMAIL")

    post sign_in_path, params: { email: "desconhecido@example.com" }

    assert_response :unprocessable_entity
    assert_select "form[action=?]", sign_in_path # continua no form de e-mail
    assert_match(/conta não existe/i, response.body)
    assert_select "a[href=?]", root_path # link "pedir acesso"
  end

  # ⚠️ Armadilha do merge (shared/_flash global): flash.now[:account_missing] é
  # uma FLAG de UI (true/false), não uma mensagem. O banner global itera todas as
  # chaves do flash; se não pular account_missing, renderiza um banner com o
  # texto literal "true". Este teste guarda contra isso.
  test "resposta de conta inexistente NÃO renderiza banner com o texto 'true'" do
    create_user(email: "conhecido@example.com")
    ENV.delete("ADMIN_EMAIL")

    post sign_in_path, params: { email: "desconhecido@example.com" }

    assert_response :unprocessable_entity
    assert_select ".flash", text: "true", count: 0
    assert_no_match(/class="flash[^"]*"[^>]*>\s*true\s*</, response.body)
  end

  # Um alert genérico (redirect de página protegida) NÃO deve ganhar o link
  # "pedir acesso" — só a conta inexistente (Q28) puxa a chave dedicada.
  # A raiz agora é a landing pública (Q36); a home protegida virou /home.
  test "redirect de página protegida para o login NÃO mostra o link Pedir acesso" do
    get home_path            # sem sessão -> redireciona pro login com flash[:alert]
    follow_redirect!

    assert_response :success
    assert_match(/Faça login para continuar/, response.body) # o alert genérico aparece
    assert_select "a[href=?]", root_path, false # mas SEM o link "pedir acesso"
  end

  # --- C: bootstrap do 1º admin via ADMIN_EMAIL -------------------------------

  test "banco vazio + e-mail == ADMIN_EMAIL cria o admin e segue o fluxo do código" do
    ENV["ADMIN_EMAIL"] = "chefe@example.com"
    assert_equal 0, User.count

    perform_enqueued_jobs do
      post sign_in_path, params: { email: "chefe@example.com" }
    end

    admin = User.find_by(email: "chefe@example.com")
    assert admin, "esperava o admin criado"
    assert admin.admin?, "o 1º user via ADMIN_EMAIL deve ser admin"
    assert ActionMailer::Base.deliveries.last, "esperava o código enviado por e-mail"
  end

  test "banco vazio + e-mail != ADMIN_EMAIL NÃO cria User" do
    ENV["ADMIN_EMAIL"] = "chefe@example.com"

    assert_no_difference -> { User.count } do
      post sign_in_path, params: { email: "estranho@example.com" }
    end
  end

  test "com user existente ADMIN_EMAIL fica inerte (não cria mesmo batendo)" do
    create_user(email: "primeiro@example.com")
    ENV["ADMIN_EMAIL"] = "chefe@example.com"

    assert_no_difference -> { User.count } do
      post sign_in_path, params: { email: "chefe@example.com" }
    end
  end

  # --- D: aviso de operador ---------------------------------------------------

  test "banco vazio + ADMIN_EMAIL em branco mostra o aviso de operador" do
    ENV.delete("ADMIN_EMAIL")
    assert_equal 0, User.count

    get sign_in_path
    assert_match(/ADMIN_EMAIL não está configurado/, response.body)
  end

  test "com user existente NÃO mostra o aviso de operador" do
    create_user(email: "alguem@example.com")
    ENV.delete("ADMIN_EMAIL")

    get sign_in_path
    assert_no_match(/ADMIN_EMAIL não está configurado/, response.body)
  end

  test "banco vazio mas ADMIN_EMAIL setado NÃO mostra o aviso de operador" do
    ENV["ADMIN_EMAIL"] = "chefe@example.com"

    get sign_in_path
    assert_no_match(/ADMIN_EMAIL não está configurado/, response.body)
  end
end
