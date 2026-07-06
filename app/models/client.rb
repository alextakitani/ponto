# Cliente do usuário (primeira tabela de domínio — Fatia 2.2). Cada Client vive na
# bolha isolada de um `user` (Q23). A rate é a taxa faturável/hora PADRÃO do cliente
# e a moeda MORA aqui (Q42); ambas nuláveis = "cliente sem taxa" (legítimo — Q2/Q15).
class Client < ApplicationRecord
  belongs_to :user

  include Archivable
  include Nameable
  name_uniqueness_scope :user_id

  # Rate faturável/hora + parser pt-BR (Ruby puro, independente de locale) — Q11/Q42.
  # O writer `rate=`, o parser e a resolução amount→cents (independente de ORDEM de
  # atribuição rate×currency) moram no concern, compartilhados com Project.
  include MonetizableRate

  # Projetos do cliente (Q22 — o Project herda a rate/moeda do Client). Q7:
  # `restrict_with_error` bloqueia o HARD-delete do Client que ainda tem projetos
  # (só arquivar). Sem projetos → hard-delete segue permitido. O controller traduz o
  # erro do restrict numa mensagem amigável (não some silenciosamente).
  has_many :projects, dependent: :restrict_with_error

  # Moeda: normaliza pra upcase ANTES de validar (o form pode mandar "brl").
  normalizes :currency, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :name, presence: true
  # Nome ÚNICO por user, INCLUINDO arquivados (Q44 — sem condição de archived_at),
  # comparando a forma normalizada (case/acento-insensitive).
  validates :currency, presence: true
  validate :currency_must_be_known

  # A colisão de nome bateu num cliente ARQUIVADO? O controller usa isto pra trocar
  # o erro cru de unicidade pela mensagem "desarquive em vez de criar outro" (Q44).
  def name_conflicts_with_archived?
    errors.include?(:name) &&
      user&.clients&.archived&.exists?(name_normalized: name_normalized)
  end

  private
    # Currency válida = existe no catálogo do gem money. Só validamos quando há um
    # valor presente (a presença em si é a validação anterior).
    def currency_must_be_known
      return if currency.blank?

      unless Money::Currency.find(currency)
        errors.add(:currency, :unknown_currency)
      end
    end
end
