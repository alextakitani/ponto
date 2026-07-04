require "test_helper"

# Resolução de locale por request (Q79). Testamos o MECANISMO — a cadeia de
# precedência param > sessão > Accept-Language > default — não a copy traduzida
# (política do projeto: view não se testa string a string). Exercitamos pela
# landing pública por ela ser anônima e conter texto de ambos os locales.
#
# Sondas de idioma (marcadores estáveis, um por locale):
#   PT: "self-hosted para quem cobra por hora" (título/description em pt-BR)
#   EN: presença do atributo lang="en" no <html> + ausência das strings PT
class LocaleResolutionTest < ActionDispatch::IntegrationTest
  PT_MARKER = "vira fatura"       # do <title>/hero, só existe em pt-BR
  EN_MARKER = "becomes the invoice" # equivalente EN do hero

  setup { create_user } # há conta -> landing normal (não o estado de operador)

  test "default é pt-BR quando não há param, sessão nem Accept-Language" do
    get root_path
    assert_locale "pt-BR"
    assert_includes response.body, PT_MARKER
  end

  test "param locale=en válido usa en" do
    get root_path(locale: "en")
    assert_locale "en"
    assert_includes response.body, EN_MARKER
  end

  test "param locale=pt-BR válido usa pt-BR" do
    get root_path(locale: "pt-BR")
    assert_locale "pt-BR"
    assert_includes response.body, PT_MARKER
  end

  test "param de locale inválido não estoura e cai no default" do
    get root_path(locale: "xx")
    assert_response :success
    assert_locale "pt-BR"
  end

  test "param válido persiste na sessão para o próximo request" do
    get root_path(locale: "en")
    assert_locale "en"

    # request seguinte SEM param herda o en da sessão
    get root_path
    assert_locale "en"
  end

  test "param sobrescreve sessão DIFERENTE já persistida e re-grava a escolha" do
    # Req 1: param en grava en na sessão.
    get root_path(locale: "en")
    assert_locale "en"

    # Req 2: param pt-BR precisa VENCER a sessão en e re-gravar pt-BR
    # (prova que a precedência é param > sessão, não o contrário).
    get root_path(locale: "pt-BR")
    assert_locale "pt-BR"

    # Req 3: sem param, herda a sessão já re-gravada como pt-BR.
    get root_path
    assert_locale "pt-BR"
  end

  test "sem param nem sessão, Accept-Language en-US resolve en" do
    get root_path, headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_locale "en"
  end

  test "sem param nem sessão, Accept-Language pt-BR resolve pt-BR" do
    get root_path, headers: { "Accept-Language" => "pt-BR,pt;q=0.9" }
    assert_locale "pt-BR"
  end

  test "Accept-Language de idioma desconhecido cai no default pt-BR" do
    get root_path, headers: { "Accept-Language" => "fr-FR,fr;q=0.9" }
    assert_locale "pt-BR"
  end

  test "param vence Accept-Language conflitante" do
    get root_path(locale: "pt-BR"), headers: { "Accept-Language" => "en-US" }
    assert_locale "pt-BR"
  end

  test "sessão vence Accept-Language conflitante" do
    get root_path(locale: "en") # grava en na sessão
    get root_path, headers: { "Accept-Language" => "pt-BR" }
    assert_locale "en"
  end

  test "preferência do usuário logado vence sessão e Accept-Language" do
    get root_path(locale: "pt-BR")
    assert_locale "pt-BR"

    user = sign_in_as("locale-user@example.com")
    user.update!(locale: "en")

    get home_path, headers: { "Accept-Language" => "pt-BR" }
    assert_locale "en"
    assert_select "h1", text: "Tracker"
    assert_includes response.body, "Add manually"
  end

  test "tela principal renderiza em en sem MissingTranslation" do
    user = sign_in_as("english-home@example.com")
    user.update!(locale: "en")

    get home_path

    assert_response :success
    assert_locale "en"
    assert_no_match(/translation missing/i, response.body)
    assert_includes response.body, "Start your first timer"
  end

  test "Accept-Language com peso maior para en escolhe en" do
    get root_path, headers: { "Accept-Language" => "pt;q=0.5, en;q=0.9" }
    assert_locale "en"
  end

  test "a página EN não vaza strings PT óbvias (fallback não expõe pt-BR)" do
    get root_path(locale: "en")
    assert_locale "en"
    refute_includes response.body, PT_MARKER
    refute_includes response.body, "Marque o ponto"
    refute_includes response.body, "Pedir acesso"
  end

  private

  # O <html lang> reflete I18n.locale (contrato do requisito C/D).
  def assert_locale(locale)
    assert_select "html[lang=?]", locale
  end
end
