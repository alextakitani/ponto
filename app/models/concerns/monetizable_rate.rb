# Rate faturável/hora (Ruby puro, Q11/Q42) compartilhada por Client e Project — o
# writer `rate=` e o parser vivem AQUI em vez de duplicados em cada model.
#
# ⚠️ NÃO incluir no TimeEntry (Fase 3): este concern é pra rate EDITÁVEL pelo usuário
# (parser de form). O snapshot do TimeEntry (Q10/Q11) é CONGELADO no before_save a
# partir de `project.effective_rate_cents` — colunas locais próprias, sem writer de
# form. É o terceiro caminho, de propósito.
#
# Por que NÃO deixamos o money-rails validar/parsear (`disable_validation: true`):
# o validator dele segue o locale do REQUEST (`Money.locale_backend = :i18n`) e, sob
# o locale default :pt-BR, lê nosso decimal canônico "150.00" como MILHAR e rejeita
# com :invalid_currency — cujo render estoura I18n::MissingTranslationData → 500 pro
# usuário pt-BR digitando o formato que o placeholder anuncia. O parsing e a validação
# da rate são NOSSOS e 100% independentes de locale.
#
# ⚠️ Ordem de atribuição: NÃO resolvemos cents no writer (senão `rate="150"` com a
# currency ainda default calcularia cents na moeda ERRADA se a currency chegar depois
# — ex.: JSON manda `{rate, currency}` nessa ordem). Guardamos a AMOUNT crua (BigDecimal)
# e convertemos pra cents só no `before_validation`, quando a currency já é a definitiva.
# Assim o resultado independe da ordem em que rate e currency foram atribuídas.
module MonetizableRate
  extend ActiveSupport::Concern

  included do
    # Dinheiro em Ruby puro. NUNCA serializar o objeto Money cru em JSON — as views
    # expõem `rate_cents` (int) + `currency` (string). allow_nil = "sem taxa" (legítimo).
    # ⚠️ `monetize` define seu PRÓPRIO `rate=` num módulo (DynamicMoneyAttributes) que
    # entra ACIMA deste concern na cadeia de ancestrais. Por isso NÃO definimos `rate=`
    # como método de módulo (perderia pro do gem) — sobrescrevemos DEPOIS, direto na
    # classe (via `define_method` no included), garantindo que o NOSSO writer vença.
    monetize :rate_cents, allow_nil: true, with_model_currency: :currency, disable_validation: true

    # Rate vinda como STRING (o form interno é SEMPRE pt-BR: "150,00"), Numeric ou Money.
    # Só guardamos a intenção aqui; a conversão pra cents acontece no before_validation
    # (quando a currency já é a definitiva) → resultado independe da ORDEM de atribuição.
    define_method(:rate=) do |value|
      @rate_input_invalid = false
      @rate_amount = nil
      @rate_cents_override = nil

      case value
      when nil, ""
        @rate_amount = nil
      when Money
        # Money já traz a própria currency resolvida → grava cents direto (sem depender
        # da currency do model, então não há ambiguidade de ordem).
        @rate_cents_override = value.cents
      when Numeric
        @rate_amount = BigDecimal(value.to_s)
      else
        if amount = parse_rate_amount(value.to_s)
          @rate_amount = amount
        else
          @rate_input_invalid = true
        end
      end
    end

    before_validation :resolve_rate_cents
    validate :rate_amount_parseable
  end

  private
    # Converte a amount crua guardada em cents, usando a currency JÁ definitiva do
    # model (roda no before_validation). Só toca `rate_cents` quando houve atribuição
    # de rate — assim carregar um record do banco e revalidar não zera a rate existente.
    def resolve_rate_cents
      if defined?(@rate_cents_override) && @rate_cents_override
        self.rate_cents = @rate_cents_override
      elsif defined?(@rate_amount)
        assign_rate_amount(@rate_amount)
      end
    end

    # Grava uma amount BigDecimal como cents (HALF_UP no centavo, como o resto do app),
    # na currency corrente do model. nil = sem taxa. Negativa é rejeitada (taxa
    # faturável não é negativa) — vira input inválido.
    def assign_rate_amount(amount)
      if amount.nil?
        self.rate_cents = nil
      elsif amount.negative?
        @rate_input_invalid = true
      else
        self.rate_cents = Money.from_amount(amount, rate_currency).cents
      end
    end

    # Currency que define a SUBUNIDADE ao converter amount→cents (JPY 0 casas, BRL 2).
    # Client TEM coluna `currency`; Project herda a do cliente OU cai no default (a
    # moeda mora no Client — Q42). Cada model define `rate_currency` conforme sua fonte;
    # o default aqui usa `currency` se o model tiver a coluna, senão o default global.
    def rate_currency
      if respond_to?(:currency) && currency.present?
        currency
      else
        Money.default_currency
      end
    end

    # Parsing determinístico da rate, INDEPENDENTE de locale. Aceita dígitos com
    # separadores "."/"," e espaços. Heurística: o ÚLTIMO separador seguido de 1–2
    # dígitos até o fim é o DECIMAL; todos os outros separadores são MILHAR (descartados).
    #   "150,00"/"150.00" -> 150 · "1.500,00"/"1,500.00" -> 1500 · "1500" -> 1500
    #   "1.500" -> 1500 (ponto é milhar, não decimal) · "150,5" -> 150.5
    # Retorna um BigDecimal, ou nil quando não dá pra parsear ("abc", "12,34,56", ...).
    def parse_rate_amount(raw)
      cleaned = raw.gsub(/\s+/, "")
      return nil if cleaned.empty?

      sign = cleaned.start_with?("-") ? "-" : ""
      digits = cleaned.sub(/\A[+-]/, "")
      # Só dígitos e separadores "."/"," a partir daqui.
      return nil unless digits.match?(/\A[\d.,]+\z/)

      # O último "." ou "," é decimal SÓ se seguido de 1–2 dígitos até o fim.
      if (m = digits.match(/[.,](\d{1,2})\z/))
        int_raw = digits[0...m.begin(0)]
        frac_part = m[1]
      else
        int_raw = digits
        frac_part = "0"
      end

      int_part = normalize_thousands(int_raw)
      return nil if int_part.nil?

      BigDecimal("#{sign}#{int_part}.#{frac_part}")
    end

    # A parte inteira: ou é só dígitos ("1500"), ou grupos de milhar separados por UM
    # único tipo de separador, com o 1º grupo de 1–3 dígitos e os demais de EXATAMENTE
    # 3 ("1.500", "1,500,000"). "12,34,56" e mistos ("1.500,000") são inválidos → nil.
    # Retorna a string só-dígitos (separadores removidos) ou nil.
    def normalize_thousands(int_raw)
      return nil if int_raw.empty?
      return int_raw if int_raw.match?(/\A\d+\z/)

      seps = int_raw.scan(/[.,]/).uniq
      return nil unless seps.size == 1

      # split(-1) preserva grupos vazios (separador no fim ou duplicado, ex. "1.." ) —
      # queremos rejeitá-los, não deixar o split engoli-los.
      groups = int_raw.split(seps.first, -1)
      return nil unless groups.first.match?(/\A\d{1,3}\z/)
      return nil unless groups.drop(1).all? { |g| g.match?(/\A\d{3}\z/) }

      groups.join
    end

    # Entrada de rate que não parseou vira erro de domínio com a mensagem PT literal
    # do projeto (nunca a chave :not_a_number/:invalid_currency do money-rails, que
    # nem tem tradução pt-BR → estouraria I18n::MissingTranslationData → 500).
    def rate_amount_parseable
      errors.add(:rate, "não é um valor válido") if @rate_input_invalid
    end
end
