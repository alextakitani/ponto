# Cliente do usuário (primeira tabela de domínio — Fatia 2.2). Cada Client vive na
# bolha isolada de um `user` (Q23). A rate é a taxa faturável/hora PADRÃO do cliente
# e a moeda MORA aqui (Q42); ambas nuláveis = "cliente sem taxa" (legítimo — Q2/Q15).
class Client < ApplicationRecord
  belongs_to :user

  include Archivable
  # Rate faturável/hora + parser pt-BR (Ruby puro, independente de locale) — Q11/Q42.
  # O writer `rate=`, o parser e a resolução amount→cents (independente de ORDEM de
  # atribuição rate×currency) moram no concern, compartilhados com Project.
  include MonetizableRate

  # Criptografia at rest (Q25c). `name` é deterministic PORQUE a unicidade/lookup por
  # igualdade precisam comparar ciphertext (o índice único bate no blob cifrado);
  # `note` é aleatório (mais forte, sem necessidade de igualdade).
  encrypts :name, deterministic: true
  encrypts :note

  # Moeda: normaliza pra upcase ANTES de validar (o form pode mandar "brl").
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

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
    # Currency válida = existe no catálogo do gem money. Só validamos quando há um
    # valor presente (a presença em si é a validação anterior).
    def currency_must_be_known
      return if currency.blank?

      unless Money::Currency.find(currency)
        errors.add(:currency, "não é uma moeda válida")
      end
    end
end
