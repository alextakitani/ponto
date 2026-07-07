require "test_helper"

# Preferências: lógica nossa de conta atual, tokens de API e isolamento por user.
class PreferencesTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("ana@example.com")
    @user.update!(name: "Ana", time_zone: "America/Sao_Paulo")
  end

  test "show renderiza perfil, tokens próprios e meus dados" do
    @user.access_tokens.create!(
      label: "Extensão",
      permission: "read",
      last_used_at: Time.zone.local(2026, 7, 3, 9, 30)
    )
    other = create_user(email: "outro@example.com")
    other.access_tokens.create!(label: "Token Alheio", permission: "write")

    get preferences_path

    assert_response :success
    assert_select "h1", text: "Preferências"
    assert_select "input[name='user[name]'][value='Ana']"
    assert_select "input[type='email'][value='ana@example.com'][disabled]"
    assert_select "body", text: /Extensão/
    assert_select "body", text: /read/
    assert_select "body", text: /Token Alheio/, count: 0
    assert_select "button[disabled]", text: /Exportar meus dados/
  end

  test "show JSON via Bearer devolve as preferências do user (contrato extensão/CLI)" do
    @user.update!(theme: "dark", accent: "mauve", locale: "pt-BR", export_locale: "en")
    token = @user.access_tokens.create!(permission: "read")

    get preferences_path(format: :json), headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success
    body = response.parsed_body
    assert_equal "pt-BR", body["locale"]
    assert_equal "dark", body["theme"]
    assert_equal "mauve", body["accent"]
    assert_equal "America/Sao_Paulo", body["time_zone"]
    assert_equal "en", body["export_locale"]
  end

  test "show JSON sem token nem sessão é rejeitado (401)" do
    # O setup faz sign_in_as (sessão de browser); sair garante que a rejeição
    # testada vem da AUSÊNCIA de credencial, não de um cookie residual.
    delete sign_out_path

    get preferences_path(format: :json)

    assert_response :unauthorized
  end

  test "update altera name e time_zone do user atual" do
    patch preferences_path, params: {
      user: { name: "Ana Paula", time_zone: "Europe/Lisbon", theme: "dark" }
    }

    assert_redirected_to preferences_path
    assert_equal "Ana Paula", @user.reload.name
    assert_equal "Europe/Lisbon", @user.time_zone
    assert_equal "dark", @user.theme
  end

  test "update com theme válido persiste e redireciona" do
    patch preferences_path, params: {
      user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "light" }
    }

    assert_redirected_to preferences_path
    assert_equal "light", @user.reload.theme
  end

  test "update com locale válido persiste" do
    patch preferences_path, params: {
      user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", locale: "en" }
    }

    assert_redirected_to preferences_path
    assert_equal "en", @user.reload.locale
  end

  test "update com accent válido persiste" do
    patch preferences_path, params: {
      user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", accent: "mauve" }
    }

    assert_redirected_to preferences_path
    assert_equal "mauve", @user.reload.accent
  end

  test "update com locale automático grava nil" do
    @user.update!(locale: "en")

    patch preferences_path, params: {
      user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", locale: "" }
    }

    assert_redirected_to preferences_path
    assert_nil @user.reload.locale
  end

  test "update persiste export_locale e volta para return_to interno" do
    return_to = reports_path(period: "custom", from: "2026-07-08", to: "2026-07-12", rounding: "on")

    patch preferences_path(return_to: return_to), params: {
      user: { export_locale: "en" }
    }

    assert_redirected_to return_to
    assert_equal "en", @user.reload.export_locale
  end

  test "update com locale forjado re-renderiza 422" do
    assert_no_changes -> { @user.reload.locale } do
      patch preferences_path, params: {
        user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", locale: "de" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "update com theme forjado não estoura 500 e re-renderiza 422" do
    assert_no_changes -> { @user.reload.theme } do
      patch preferences_path, params: {
        user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "hotdog" }
      }
    end

    assert_response :unprocessable_entity
    assert_match(/Tema/, response.body)
    assert_no_match(/data-theme="hotdog"/, response.body)
  end

  test "update com accent forjado re-renderiza 422 sem alterar o registro" do
    @user.update!(accent: "teal")

    assert_no_changes -> { @user.reload.accent } do
      patch preferences_path, params: {
        user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", accent: "vermelho" }
      }
    end

    assert_response :unprocessable_entity
    assert_no_match(/data-accent="vermelho"/, response.body)
  end

  test "layout autenticado renderiza data-accent no body" do
    @user.update!(accent: "pink")

    get preferences_path

    assert_response :success
    assert_select "body.app[data-accent='pink']"
  end

  test "update rejeita time_zone inválido" do
    patch preferences_path, params: {
      user: { name: "Ana Invadida", time_zone: "Mars/Olympus_Mons" }
    }

    assert_response :unprocessable_entity
    assert_equal "Ana", @user.reload.name
    assert_equal "America/Sao_Paulo", @user.time_zone
    assert_match(/Fuso horário inválido/, response.body)
  end

  test "update sem time_zone no payload NÃO estoura 500 (só edita o name)" do
    # PATCH parcial (curl/CLI) sem a chave time_zone: TimeZone[nil] levanta
    # ArgumentError no Rails 8.1 — tem que degradar pra sucesso (mantém o fuso).
    patch preferences_path, params: { user: { name: "Só o nome" } }

    assert_response :redirect
    assert_equal "Só o nome", @user.reload.name
    assert_equal "America/Sao_Paulo", @user.time_zone
  end

  test "update NÃO permite escalar privilégio (admin/suspended_at) via mass-assignment" do
    # Segurança: o perfil só edita name/time_zone. Se admin/suspended_at fossem
    # mass-assignable aqui, um user comum viraria admin ou se des-suspenderia sozinho.
    refute @user.admin?
    patch preferences_path, params: {
      user: { name: "Ana", time_zone: "America/Sao_Paulo", theme: "system", admin: true, suspended_at: nil }
    }

    assert_not @user.reload.admin?, "não deve escalar para admin via /preferences"
  end

  test "update ignora tentativa de editar outra conta" do
    other = create_user(email: "outra@example.com")
    other.update!(name: "Outra", time_zone: "UTC")

    patch preferences_path, params: {
      id: other.id,
      user: { name: "Ana Local", email: "hack@example.com", time_zone: "America/Fortaleza" }
    }

    assert_redirected_to preferences_path
    assert_equal "Ana Local", @user.reload.name
    assert_equal "ana@example.com", @user.email
    assert_equal "Outra", other.reload.name
    assert_equal "UTC", other.time_zone
  end

  test "create token persiste permission e mostra token só uma vez" do
    assert_difference -> { @user.access_tokens.count }, +1 do
      post preferences_access_tokens_path, params: {
        access_token: { label: "CLI", permission: "write" }
      }
    end

    token = @user.access_tokens.find_by!(label: "CLI")
    assert_equal "write", token.permission
    assert_redirected_to preferences_path
    follow_redirect!
    assert_select "body", text: /CLI/
    assert_select "body", text: /write/
    assert_select "code", text: token.token

    get preferences_path
    assert_response :success
    assert_select "body", text: /CLI/
    assert_select "body", text: token.token, count: 0
  end

  test "create token com permission fora do enum NÃO estoura 500 (422)" do
    # Request forjado (curl) com permission inválida: o enum levantaria ArgumentError
    # antes do save → 500. Tem que virar 422 sem criar token.
    assert_no_difference -> { @user.access_tokens.count } do
      post preferences_access_tokens_path, params: {
        access_token: { label: "Hack", permission: "root" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "destroy revoga token próprio" do
    token = @user.access_tokens.create!(label: "Velho", permission: "read")

    assert_difference -> { @user.access_tokens.count }, -1 do
      delete access_token_path(token)
    end

    assert_redirected_to preferences_path
    assert_not AccessToken.exists?(token.id)
  end

  test "destroy de token alheio dá 404" do
    other = create_user(email: "token-owner@example.com")
    token = other.access_tokens.create!(label: "Alheio", permission: "read")

    assert_no_difference -> { AccessToken.count } do
      delete access_token_path(token)
    end

    assert_response :not_found
    assert AccessToken.exists?(token.id)
  end
end
