require "test_helper"

# Fluxo de controle NOSSO do pedido de acesso público (Q24):
# delega ao AccessRequest.record (de-dup) e SEMPRE responde genérico
# (anti-enumeração) — independente de já existir conta ou pedido.
class AccessRequestsTest < ActionDispatch::IntegrationTest
  # Resposta genérica (anti-enumeração): idêntica nos 3 casos. Lida via I18n.t
  # (Q79) em vez de string literal — a semântica "resposta única" é o que importa,
  # não a copy. Sem locale no request, resolve no default pt-BR.
  GENERIC = I18n.t("access_requests.create.received")

  # Regressão (06/07): o form da landing enviava campos SOLTOS (sem scope) e o
  # controller exige o wrapper access_request → ParameterMissing 400 silencioso,
  # pedido nunca gravado. O contrato do form (atributo name) é o seam que trava isso.
  test "form da landing aninha os campos no wrapper access_request" do
    create_user # bootstrap feito — senão a landing mostra o aviso de operador, não o form
    get root_path

    assert_select "form[action=?]", access_requests_path do
      assert_select "input[name=?]", "access_request[email]"
      assert_select "input[name=?]", "access_request[name]"
      assert_select "textarea[name=?]", "access_request[note]"
    end
  end

  test "pedido novo cria um AccessRequest pending" do
    assert_difference -> { AccessRequest.pending.count }, +1 do
      post access_requests_path, params: { access_request: { email: "novo@example.com" } }
    end

    follow_redirect!
    assert_match GENERIC, response.body
  end

  test "e-mail de conta existente não cria pedido, resposta genérica" do
    create_user(email: "conta@example.com")

    assert_no_difference -> { AccessRequest.count } do
      post access_requests_path, params: { access_request: { email: "conta@example.com" } }
    end

    follow_redirect!
    assert_match GENERIC, response.body
  end

  test "pedido pending existente não duplica e atualiza a note" do
    first = AccessRequest.record(email: "dup@example.com", note: "primeira")

    assert_no_difference -> { AccessRequest.count } do
      post access_requests_path, params: { access_request: { email: "dup@example.com", note: "segunda" } }
    end

    assert_equal "segunda", first.reload.note
    follow_redirect!
    assert_match GENERIC, response.body
  end

  test "e-mail em branco/ausente não estoura 500; resposta genérica" do
    assert_no_difference -> { AccessRequest.count } do
      post access_requests_path, params: { access_request: { email: "" } }
    end

    follow_redirect!
    assert_match GENERIC, response.body
  end

  test "público: não exige autenticação" do
    post access_requests_path, params: { access_request: { email: "anon@example.com" } }

    assert_response :redirect
    assert_no_match(/sign_in/, response.location)
  end
end
