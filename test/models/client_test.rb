require "test_helper"

# Lógica NOSSA do Client (Fatia 2.2): unicidade de nome por user INCLUINDO
# arquivados (Q44) e normalização/validação de currency. Não testamos o
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

  # A unicidade também é garantida no BANCO (índice único sobre name_normalized) —
  # não só na validação.
  test "índice único do banco barra duplicata quando a validação é pulada" do
    @user.clients.create!(name: "Acme")

    assert_raises ActiveRecord::RecordNotUnique do
      dup = @user.clients.build(name: "Acme")
      dup.name_normalized = Client.normalize_name(dup.name)
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

  # --- Rate: parsing determinístico, INDEPENDENTE de locale (regressão) --------
  # O form interno é sempre pt-BR ("150,00"), mas o validator do money-rails segue o
  # locale do request (Money.locale_backend = :i18n). No locale DEFAULT (:pt-BR) o
  # gem lia "150.00" (nosso decimal canônico) como milhar e REJEITAVA com
  # :invalid_currency → render do erro estourava I18n::MissingTranslationData → 500.
  # Agora o writer `rate=` faz parsing próprio (heurística do último separador) e
  # atribui `rate_cents` direto, sem NUNCA delegar string crua pro money-rails.

  # 1) RED contra o código antigo: sob o locale DEFAULT (sem with_locale) o form
  # pt-BR tem que ser aceito e virar 15000 cents.
  test "rate pt-BR '150,00' é válida e vira 15000 cents no locale DEFAULT" do
    client = @user.clients.new(name: "Default", currency: "BRL")
    client.rate = "150,00"

    assert client.valid?, client.errors.full_messages.to_sentence
    assert_equal 15000, client.rate_cents
  end

  # 2) Tabela canônica: o MESMO input dá o MESMO resultado nos dois locales — o
  # parsing não pode depender do locale do request.
  RATE_CASES = {
    "150,00"    => 15000,   # decimal pt-BR
    "150.00"    => 15000,   # decimal en (ponto)
    "1.500,00"  => 150000,  # milhar pt-BR
    "1,500.00"  => 150000,  # milhar en
    "1500"      => 150000,  # inteiro puro
    "1.500"     => 150000,  # ponto como MILHAR (não decimal): 1500
    "150,5"     => 15050,   # 1 dígito decimal
    ""          => nil,     # vazio = sem taxa
    nil         => nil      # nil = sem taxa
  }.freeze

  test "tabela de rate: mesmo cents em :pt-BR e :en (parsing independente de locale)" do
    [ :"pt-BR", :en ].each do |locale|
      I18n.with_locale(locale) do
        RATE_CASES.each do |input, expected_cents|
          client = @user.clients.new(name: "Case-#{locale}-#{input.inspect}", currency: "BRL")
          client.rate = input

          assert client.valid?, "[#{locale}] #{input.inspect}: #{client.errors.full_messages.to_sentence}"
          if expected_cents.nil?
            assert_nil client.rate_cents, "[#{locale}] #{input.inspect} devia virar nil"
          else
            assert_equal expected_cents, client.rate_cents,
              "[#{locale}] #{input.inspect} devia virar #{expected_cents} cents"
          end
        end
      end
    end
  end

  # 3) Entrada não-parseável: inválida com a mensagem PT, SEM levantar exceção.
  test "rate não-parseável é inválida com mensagem PT (sem 500)" do
    [ "abc", "12,34,56" ].each do |bad|
      client = @user.clients.new(name: "Bad-#{bad}", currency: "BRL")

      assert_nothing_raised { client.rate = bad }
      assert_not client.valid?, "#{bad.inspect} deveria ser inválido"
      assert_includes client.errors[:rate], "não é um valor válido"
    end
  end

  test "rate negativa é inválida" do
    client = @user.clients.new(name: "Negativa", currency: "BRL")
    client.rate = "-150,00"

    assert_not client.valid?
    assert_includes client.errors[:rate], "não é um valor válido"
  end

  # --- Rate × currency: independente de ORDEM de atribuição (regressão) ---------
  # O caller JSON pode mandar rate ANTES da currency (a ordem do hash de params).
  # Se resolvêssemos cents no writer `rate=` (como antes), "150" com currency ainda
  # BRL viraria 15000 cents; ao chegar a currency JPY (sem subunidade), o cents certo
  # é 150. Agora o amount cru fica guardado e vira cents só no before_validation, com
  # a currency JÁ definitiva — o resultado independe da ordem.
  test "rate atribuída ANTES da currency resolve cents na moeda final (JPY)" do
    client = @user.clients.new(name: "Yen")
    client.rate = "150"        # rate primeiro
    client.currency = "JPY"    # currency depois

    assert client.valid?, client.errors.full_messages.to_sentence
    # JPY não tem subunidade (0 decimais) → 150 é 150 cents, não 15000.
    assert_equal 150, client.rate_cents
  end

  test "currency atribuída antes da rate dá o mesmo resultado (JPY)" do
    client = @user.clients.new(name: "Yen2", currency: "JPY")
    client.rate = "150"

    assert client.valid?
    assert_equal 150, client.rate_cents
  end

  test "trocar a currency depois recalcula os cents da rate crua (BRL→JPY)" do
    client = @user.clients.new(name: "Muda", currency: "BRL")
    client.rate = "150"
    client.valid?
    assert_equal 15000, client.rate_cents  # BRL: 2 decimais

    client.currency = "JPY"
    client.valid?
    assert_equal 150, client.rate_cents    # JPY: 0 decimais
  end

  # --- Tradução do atributo `rate` (UX da mensagem de erro) --------------------
  # `full_messages` humaniza o atributo: sem tradução vinha "Rate não é um valor
  # válido" (inglês cru no meio do PT). Com o locale activerecord.client.rate a
  # mensagem completa vira "Valor por hora não é um valor válido".
  test "erro de rate usa o rótulo PT 'Valor por hora' na mensagem completa" do
    client = @user.clients.new(name: "Rotulo", currency: "BRL")
    client.rate = "abc"
    client.valid?

    assert_includes client.errors.full_messages, "Valor por hora não é um valor válido"
  end

  # --- Hard-delete restrito por projetos (Q7) ---------------------------------

  test "cliente COM projeto não é hard-deletado (restrict_with_error)" do
    client = @user.clients.create!(name: "ComProjeto")
    @user.projects.create!(name: "P1", client: client)

    assert_no_difference -> { Client.count } do
      assert_not client.destroy
    end
    assert client.errors[:base].present?
  end

  test "cliente SEM projeto é hard-deletado normalmente" do
    client = @user.clients.create!(name: "SemProjeto")

    assert_difference -> { Client.count }, -1 do
      assert client.destroy
    end
  end
end
