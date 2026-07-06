require "test_helper"

class WelcomeTest < ActionDispatch::IntegrationTest
  test "user HTML por sessão sem onboarding é redirecionado para welcome" do
    sign_in_as("novo@example.com", user: create_user(email: "novo@example.com", onboarded_at: nil))

    get home_path

    assert_redirected_to welcome_path
  end

  test "admin não sofre redirect automático" do
    admin = create_user(email: "admin@example.com", admin: true, onboarded_at: nil)
    sign_in_as("admin@example.com", user: admin)

    get home_path

    assert_response :success
  end

  test "request JSON com Bearer AccessToken não redireciona para welcome" do
    user = create_user(email: "ext@example.com", onboarded_at: nil)
    token = user.access_tokens.create!(permission: "read")

    get timer_path, headers: bearer(token), as: :json

    assert_response :success
  end

  test "skip grava onboarded_at, cai em home e libera navegação seguinte" do
    user = create_user(email: "skip@example.com", onboarded_at: nil)
    sign_in_as("skip@example.com", user: user)

    post onboarding_skip_path

    assert_redirected_to home_path
    assert user.reload.onboarded_at.present?

    get home_path
    assert_response :success
  end

  test "welcome redireciona para home quando onboarding já foi concluído" do
    user = create_user(email: "feito@example.com", onboarded_at: Time.current)
    sign_in_as("feito@example.com", user: user)

    get welcome_path

    assert_redirected_to home_path
  end

  # Guarda de render: a welcome reusa chaves i18n de Preferências (que vivem sob
  # preferences.show.profile.*) — um caminho errado só estoura ao renderizar, não
  # nos testes de fluxo. Roda nos dois locales.
  test "welcome renderiza os quick settings e o link de preferências nos dois idiomas" do
    user = create_user(email: "render@example.com", onboarded_at: nil, theme: "dark", locale: "en")
    sign_in_as("render@example.com", user: user)

    %w[pt-BR en].each do |locale|
      get welcome_path(locale: locale)

      assert_response :success
      assert_select ".quick-settings[data-controller=theme]"
      # idioma + tema como <select> nativos (submetem no change)
      assert_select "select[name='user[locale]']"
      assert_select "select[name='user[theme]']"
      assert_select "a[href=?]", preferences_path
    end
  end

  test "toggle de idioma na welcome persiste o locale e volta pra welcome sem flash" do
    user = create_user(email: "lang@example.com", onboarded_at: nil, locale: nil)
    sign_in_as("lang@example.com", user: user)

    patch preferences_path, params: { user: { locale: "en" }, return_to: welcome_path(locale: "en") }

    assert_equal "en", user.reload.locale
    assert_redirected_to welcome_path(locale: "en")
    # um toggle não é "salvar o form" — não dispara o flash de Preferências atualizadas
    # (o "Bem-vindo!" residual do login é outro flash, não este).
    assert_not_equal I18n.t("preferences.update.updated"), flash[:notice]
  end

  test "toggle de tema na welcome persiste o theme e volta pra welcome" do
    user = create_user(email: "theme@example.com", onboarded_at: nil, theme: "system")
    sign_in_as("theme@example.com", user: user)

    patch preferences_path, params: { user: { theme: "dark" }, return_to: welcome_path }

    assert_equal "dark", user.reload.theme
    assert_redirected_to welcome_path
  end

  # Segurança: return_to só pode ser caminho interno — nunca um host externo.
  test "return_to externo é ignorado (anti open-redirect)" do
    user = create_user(email: "evil@example.com", onboarded_at: nil)
    sign_in_as("evil@example.com", user: user)

    patch preferences_path, params: { user: { theme: "dark" }, return_to: "https://evil.example.com" }

    assert_redirected_to preferences_path
    assert_no_match %r{evil\.example\.com}, response.location.to_s
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
