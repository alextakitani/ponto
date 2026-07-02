# Cliente do usuário (primeira tabela de domínio — Fatia 2.2). Cada Client vive na
# bolha isolada de um `user` (Q23). A rate é a taxa faturável/hora PADRÃO do cliente
# e a moeda MORA aqui (Q42); ambas nuláveis = "cliente sem taxa" (legítimo — Q2/Q15).
class Client < ApplicationRecord
  belongs_to :user

  include Archivable

  # Dinheiro em Ruby puro (Q11/Q42). NUNCA serializar o objeto Money cru em JSON —
  # as views expõem `rate_cents` (int) + `currency` (string). allow_nil = sem taxa.
  monetize :rate_cents, allow_nil: true, with_model_currency: :currency

  # Criptografia at rest (Q25c). `name` é deterministic PORQUE a unicidade/lookup por
  # igualdade precisam comparar ciphertext (o índice único bate no blob cifrado);
  # `note` é aleatório (mais forte, sem necessidade de igualdade).
  encrypts :name, deterministic: true
  encrypts :note

  # Moeda: normaliza pra upcase ANTES de validar (o form pode mandar "brl").
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

  # Rate vinda do form como STRING pt-BR ("150,00"). A UI interna é SEMPRE pt-BR
  # (vírgula decimal), mas o `Money.locale_backend = :i18n` faz o validator do
  # money-rails seguir o locale do REQUEST (que pode ser :en se o browser mandar
  # Accept-Language en) — aí "150,00" seria rejeitado. Normalizamos o input pra um
  # decimal canônico (ponto) ANTES do money-rails ver, deixando o parsing
  # independente de locale. Aceita "150,00", "1.500,00" e "150.00"; número/Money
  # passam direto. Cadeia de accessors do money-rails preservada via super.
  def rate=(value)
    super(normalize_rate_input(value))
  end

  validates :name, presence: true
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
    # "150,00" -> "150.00"; "1.500,50" -> "1500.50"; "150.00" -> "150.00".
    # Regra: se há vírgula, ela é o decimal (pt-BR) e o ponto é milhar → tira pontos,
    # vírgula vira ponto. Sem vírgula, o ponto já é o decimal → passa direto. Valores
    # não-string (Numeric/Money/nil) passam intactos pro money-rails.
    def normalize_rate_input(value)
      if value.is_a?(String) && value.include?(",")
        value.delete(".").tr(",", ".")
      else
        value
      end
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
