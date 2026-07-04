# Projeto do usuário (Fatia 2.3) — sub-bucket do Client na hierarquia
# Client→Project→Task. Vive na bolha isolada de um `user` (Q23). O cliente é
# OPCIONAL (Q2); a rate é um OVERRIDE opcional da rate do cliente (Q22); a cor sai
# de uma paleta fixa curada (Q52).
class Project < ApplicationRecord
  belongs_to :user
  # Cliente OPCIONAL (Q2). ⚠️ Precisa ser do MESMO user — a FK não conhece bolhas,
  # então validamos o dono explicitamente (senão o form de A poderia apontar client
  # de B mandando o id cru). Ver `client_belongs_to_user`.
  belongs_to :client, optional: true
  has_many :time_entries, dependent: :destroy
  has_many :tasks, dependent: :destroy

  include Archivable
  # Rate + parser pt-BR compartilhados com o Client (Ruby puro, independente de
  # locale E de ordem de atribuição — Q11/Q22). O writer `rate=` e o `rate_cents`
  # override vivem no concern.
  include MonetizableRate

  # Criptografia at rest (Q25c). `name` deterministic pela unicidade/lookup por
  # igualdade (o índice único bate no ciphertext), como no Client.
  encrypts :name, deterministic: true

  # Paleta fixa curada (Q52) — 12 cores com contraste sobre fundo claro E escuro
  # (Q64: dark automático). Tons ~Tailwind 500/600, evitando muito claro/escuro.
  # A UI só oferece estes swatches; o MODEL valida FORMATO (não inclusão) → a paleta
  # pode evoluir sem invalidar cor antiga (Q52). São 12 → um projeto por cor antes de
  # repetir (a auto-atribuição escolhe a menos usada).
  PALETTE = %w[
    #e05252 #e07a3c #d9a520 #4c9a4c
    #2f9e8f #2f7fd1 #4f5ed9 #7b52c9
    #c0479e #8a6d3b #5b7083 #b0863c
  ].freeze

  # A moeda MORA no Client (Q42). Projeto SEM cliente e COM rate própria não tem moeda
  # herdável → adotamos o default global (BRL) e documentamos: rate sem cliente é caso
  # de borda (Q2 diz que projeto sem cliente normalmente fica sem valor). Não guardamos
  # currency no Project (o snapshot da Fase 3 congela moeda no TimeEntry).
  FALLBACK_CURRENCY = "BRL"

  validates :name, presence: true
  # Nome ÚNICO por user, INCLUINDO arquivados (Q44). UX de colisão-com-arquivado no form.
  validates :name, uniqueness: { scope: :user_id, message: :taken }
  validates :color, presence: true, format: {
    with: /\A#\h{6}\z/, message: :invalid_color
  }
  validate :client_belongs_to_user

  # Pré-seleciona a cor MENOS USADA entre os projetos ATIVOS do user (Q52) → o donut
  # dos relatórios (Q21) nasce sem fatias de cor repetida sem o usuário pensar nisso.
  before_validation :assign_least_used_color, on: :create, if: -> { color.blank? }

  # Tasks ATIVAS ordenadas por nome (case-insensitive), materializadas em memória —
  # `name` é criptografado (Q25c), então o ORDER BY do SQLite bateria no ciphertext.
  # Fonte única do "tasks.active ordenado" que os controllers e o partial `_section` usam.
  def active_tasks
    tasks.active.to_a.sort_by { |t| t.name.downcase }
  end

  # Rate EFETIVA (Q22): override do projeto, senão a do cliente, senão nil.
  # Congela no snapshot do TimeEntry (Fase 3); a UI e o JSON expõem já resolvida.
  def effective_rate_cents
    if rate_cents
      rate_cents
    else
      client&.rate_cents
    end
  end

  # Moeda que acompanha a rate efetiva. A moeda mora no Client (Q42): se a rate vem do
  # cliente (herança) ou o projeto tem cliente, use a do cliente. Projeto SEM cliente
  # COM rate própria → BRL default (ver FALLBACK_CURRENCY). Sem rate efetiva → nil
  # (não há dinheiro a exibir).
  def effective_currency
    if effective_rate_cents.nil?
      nil
    elsif client
      client.currency
    else
      FALLBACK_CURRENCY
    end
  end

  # A rate efetiva é HERDADA do cliente (não é override próprio do projeto)? A UI marca
  # o valor como "do cliente" em muted quando true.
  def rate_inherited?
    rate_cents.nil? && client&.rate_cents.present?
  end

  # A colisão de nome bateu num projeto ARQUIVADO? O form troca o erro cru de
  # unicidade pela mensagem "desarquive em vez de criar outro" (Q44), como no Client.
  def name_conflicts_with_archived?
    errors.include?(:name) &&
      user&.projects&.archived&.exists?(name: name)
  end

  private
    # A moeda que define a SUBUNIDADE ao gravar o override em cents (Q42): a do cliente
    # se houver, senão o default (BRL) — coerente com effective_currency. O concern
    # MonetizableRate chama isto pra saber quantas casas decimais a currency tem.
    def rate_currency
      client&.currency || FALLBACK_CURRENCY
    end

    # A cor menos usada entre os projetos ativos do user. Começa com toda a paleta
    # zerada (cores nunca usadas contam 0) e escolhe a de menor contagem — determinístico
    # (a paleta é ordenada, então o primeiro empate vence sempre).
    def assign_least_used_color
      counts = PALETTE.index_with { 0 }
      user&.projects&.active&.each do |project|
        counts[project.color] += 1 if counts.key?(project.color)
      end
      self.color = counts.min_by { |_color, count| count }.first
    end

    # Cliente apontado tem que ser do MESMO user (isolamento Q23). Compara user_id sem
    # carregar o record alheio inteiro. Sem cliente = ok (Q2).
    def client_belongs_to_user
      if client && client.user_id != user_id
        errors.add(:client, :not_owned)
      end
    end
end
