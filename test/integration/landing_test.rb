require "test_helper"

# Fluxo de controle NOSSO da landing pública (Q36/Q67):
#   - anônimo em / -> landing pública (200)
#   - logado em /  -> redirect pra home autenticada
#   - estado de operador (Q38): sem contas e sem ADMIN_EMAIL -> aviso, sem form
class LandingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "anônimo em / vê a landing pública com o form de pedir acesso" do
    create_user # já há conta -> não é o estado de bootstrap do operador

    get root_path

    assert_response :success
    assert_select "form[action=?]", access_requests_path
  end

  test "logado em / é redirecionado pra home autenticada" do
    sign_in_as "alex@example.com"

    get root_path
    assert_redirected_to home_path
  end

  test "sem contas e sem ADMIN_EMAIL mostra aviso de operador, não o form" do
    User.delete_all
    with_admin_email(nil) do
      get root_path
    end

    assert_response :success
    assert_select "form[action=?]", access_requests_path, count: 0
    assert_match(/ADMIN_EMAIL/, response.body)
  end

  test "sem contas mas COM ADMIN_EMAIL mostra o form normalmente" do
    User.delete_all
    with_admin_email("admin@example.com") do
      get root_path
    end

    assert_response :success
    assert_select "form[action=?]", access_requests_path
  end

  private

  def with_admin_email(value)
    original = ENV["ADMIN_EMAIL"]
    ENV["ADMIN_EMAIL"] = value
    yield
  ensure
    ENV["ADMIN_EMAIL"] = original
  end
end
