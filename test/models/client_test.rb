require "test_helper"

# Lógica NOSSA do Client (Fatia 2.2): unicidade de nome por user INCLUINDO
# arquivados (Q44), normalização/validação de currency, e a sanidade da
# criptografia (Q25c — name não vaza em claro no SQL). Não testamos o
# `belongs_to`/`monetize` (framework/gem).
class ClientTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  # --- Unicidade de nome por user, incluindo arquivados (Q44) ------------------

  test "nome duplicado no mesmo user é barrado pela validação" do
    @user.clients.create!(name: "Acme")

    dup = @user.clients.build(name: "Acme")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "já está em uso"
  end

  test "nome duplicado colide mesmo quando o original está ARQUIVADO (Q44)" do
    original = @user.clients.create!(name: "Acme")
    original.archive!

    dup = @user.clients.build(name: "Acme")
    assert_not dup.valid?
    assert dup.name_conflicts_with_archived?
  end

  test "users DIFERENTES podem repetir o mesmo nome" do
    @user.clients.create!(name: "Acme")
    outro = create_user(email: "outro@example.com")

    assert outro.clients.build(name: "Acme").valid?
  end

  # A unicidade também é garantida no BANCO (índice único sobre o ciphertext
  # deterministic) — não só na validação.
  test "índice único do banco barra duplicata quando a validação é pulada" do
    @user.clients.create!(name: "Acme")

    assert_raises ActiveRecord::RecordNotUnique do
      dup = @user.clients.build(name: "Acme")
      dup.save!(validate: false)
    end
  end

  # --- Currency: presença, validade e normalização ----------------------------

  test "currency é normalizada pra upcase" do
    client = @user.clients.create!(name: "Euro", currency: "eur")
    assert_equal "EUR", client.currency
  end

  test "currency inexistente no gem money é inválida" do
    client = @user.clients.build(name: "Fake", currency: "XYZ")
    assert_not client.valid?
    assert_includes client.errors[:currency], "não é uma moeda válida"
  end

  test "currency em branco é inválida" do
    client = @user.clients.build(name: "Sem moeda", currency: "")
    assert_not client.valid?
  end

  # --- Rate pt-BR independente de locale (regressão de bug real) --------------
  # O form interno é sempre pt-BR ("150,00"), mas o validator do money-rails segue
  # o locale do request (Money.locale_backend = :i18n). Sob locale :en, "150,00"
  # era REJEITADO. Normalizamos o input no writer pra o parsing não depender do locale.

  test "rate pt-BR '150,00' vira 15000 cents E é válida mesmo sob locale :en" do
    I18n.with_locale(:en) do
      client = @user.clients.new(name: "PtBr", currency: "BRL")
      client.rate = "150,00"

      assert client.valid?, client.errors.full_messages.to_sentence
      assert_equal 15000, client.rate_cents
    end
  end

  test "rate com milhar pt-BR '1.500,50' vira 150050 cents" do
    client = @user.clients.new(name: "Milhar", currency: "BRL")
    client.rate = "1.500,50"

    assert_equal 150050, client.rate_cents
  end

  test "rate estilo ponto-decimal '150.00' continua funcionando" do
    client = @user.clients.new(name: "Ponto", currency: "BRL")
    client.rate = "150.00"

    assert_equal 15000, client.rate_cents
  end

  # --- Encryption sanity (Q25c) -----------------------------------------------

  test "name não aparece em claro no SQL cru (criptografado at rest)" do
    @user.clients.create!(name: "SegredoIndustrial")

    raw = ActiveRecord::Base.connection.select_value("SELECT name FROM clients LIMIT 1")
    assert_not_nil raw
    assert_not_includes raw, "SegredoIndustrial"
  end
end
