# Cliente do usuário (primeira tabela de domínio — Fatia 2.2). Cada Client vive na
# bolha isolada de um `user` (Q23). A rate é a taxa faturável/hora PADRÃO do cliente
# e a moeda MORA aqui (Q42); ambas nuláveis = "cliente sem taxa" (legítimo — Q2/Q15).
class Client < ApplicationRecord
  belongs_to :user

  include Archivable

  # Dinheiro em Ruby puro (Q11/Q42). NUNCA serializar o objeto Money cru em JSON —
  # as views expõem `rate_cents` (int) + `currency` (string). allow_nil = sem taxa.
  #
  # `disable_validation: true` (Q42): NÃO deixamos o money-rails validar. O validator
  # dele segue o locale do request (Money.locale_backend = :i18n) e, sob o locale
  # default :pt-BR, lia nosso decimal canônico "150.00" como MILHAR e rejeitava com
  # :invalid_currency — cujo render estourava I18n::MissingTranslationData → 500 pro
  # usuário pt-BR digitando o formato que o placeholder anuncia. O parsing e a
  # validação da rate são NOSSOS (writer `rate=` + `rate_amount_parseable`), 100%
  # independentes de locale. O getter `rate` (Money) do gem continua valendo.
  monetize :rate_cents, allow_nil: true, with_model_currency: :currency, disable_validation: true

  # Criptografia at rest (Q25c). `name` é deterministic PORQUE a unicidade/lookup por
  # igualdade precisam comparar ciphertext (o índice único bate no blob cifrado);
  # `note` é aleatório (mais forte, sem necessidade de igualdade).
  encrypts :name, deterministic: true
  encrypts :note

  # Moeda: normaliza pra upcase ANTES de validar (o form pode mandar "brl").
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

  # Rate vinda do form como STRING (a UI interna é SEMPRE pt-BR: "150,00"), mas o
  # parsing é NOSSO e INDEPENDENTE de locale (o locale escolhido na landing vaza pro
  # app; não podemos depender dele). Convertendo pra cents aqui e atribuindo direto,
  # NUNCA delegamos string crua pro money-rails (que validaria segundo o locale do
  # request). Número/Money são resolvidos via Money.from_amount. Entrada inválida
  # deixa uma marca pra `rate_amount_parseable` reportar com a mensagem PT do projeto.
  def rate=(value)
    @rate_input_invalid = false

    case value
    when nil, ""
      self.rate_cents = nil
    when Money
      self.rate_cents = value.cents
    when Numeric
      assign_rate_amount(BigDecimal(value.to_s))
    else
      amount = parse_rate_amount(value.to_s)
      amount ? assign_rate_amount(amount) : (@rate_input_invalid = true)
    end
  end

  validates :name, presence: true
  validate :rate_amount_parseable
  # Nome ÚNICO por user, INCLUINDO arquivados (Q44 — sem condição de archived_at).
  # A colisão-com-arquivado ganha UX própria no controller (não o erro cru).
  validates :name, uniqueness: { scope: :user_id, message: "já está em uso" }
  validates :currency, presence: true
  validate :currency_must_be_known

  # A colisão de nome bateu num cliente ARQUIVADO? O controller usa isto pra trocar
  # o erro cru de unicidade pela mensagem "desarquive em vez de criar outro" (Q44).
  def name_conflicts_with_archived?
    errors.include?(:name) &&
      user&.clients&.archived&.exists?(name: name)
  end

  private
    # Grava uma amount BigDecimal como cents (HALF_UP no centavo, como o resto do app).
    # Negativa é rejeitada (taxa faturável não é negativa) — vira input inválido.
    def assign_rate_amount(amount)
      if amount.negative?
        @rate_input_invalid = true
      else
        self.rate_cents = Money.from_amount(amount, currency || Money.default_currency).cents
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

    # Currency válida = existe no catálogo do gem money. Só validamos quando há um
    # valor presente (a presença em si é a validação anterior).
    def currency_must_be_known
      return if currency.blank?

      unless Money::Currency.find(currency)
        errors.add(:currency, "não é uma moeda válida")
      end
    end
end
