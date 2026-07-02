require "test_helper"

# Autenticação por Bearer (extensão de Chrome) — lógica NOSSA do concern:
# só vale em JSON e respeita o escopo de método do token.
class BearerAuthTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "ext@example.com")
    @read = @user.access_tokens.create!(permission: "read")
  end

  # home_path é uma página PROTEGIDA (require_authentication). root_path virou a
  # landing pública (Q36), então o exercício do concern usa a home.
  test "Bearer em request JSON autentica (não redireciona pro login)" do
    get home_path, headers: bearer(@read), as: :json
    assert_not_equal 302, response.status
    assert_not_equal 401, response.status
  end

  test "request JSON sem token é rejeitado com 401" do
    get home_path, as: :json
    assert_response :unauthorized
  end

  test "Bearer é ignorado em request HTML: cai no fluxo de login (302)" do
    get home_path, headers: bearer(@read)
    assert_redirected_to sign_in_path
  end

  test "token sem escrita não autoriza método de escrita (401, não 422 de CSRF)" do
    delete sign_out_path, headers: bearer(@read), as: :json
    assert_response :unauthorized
  end

  test "token de escrita autoriza método de escrita" do
    write = @user.access_tokens.create!(permission: "write")

    delete sign_out_path, headers: bearer(write), as: :json
    assert_not_equal 401, response.status
  end

  private

  def bearer(token)
    { "Authorization" => "Bearer #{token.token}" }
  end
end
