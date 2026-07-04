class AccessRequest < ApplicationRecord
  # Resolver (approve!/reject!) só faz sentido a partir de pending; reprocessar um
  # request já aprovado/recusado é erro de fluxo, não no-op silencioso (Q35).
  InvalidTransition = Class.new(StandardError)

  # Pré-conta (Q24): pedido público de acesso, fora do isolamento por usuário.
  # O admin aprova/recusa depois (Task 1.4); aqui só registramos.
  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  # Mesmo padrão de enum-string do resto do app (AccessToken).
  attribute :status, :string, default: "pending"
  enum :status, %w[pending approved rejected].index_by(&:itself)

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Registra um pedido de acesso sem revelar o resultado (anti-enumeração):
  #   - já existe User com o e-mail        -> não cria nada
  #   - já existe pedido pending com ele   -> atualiza a note, não duplica
  #   - caso contrário                     -> cria um pending novo
  # Sempre retorna sem sinalizar qual caso ocorreu.
  def self.record(email:, name: nil, note: nil)
    email = User.normalize_value_for(:email, email)

    if email.blank?
      # E-mail em branco/ausente: silêncio (o form pede e-mail; não revelamos nada).
    elsif User.exists?(email: email)
      # Já é conta: silêncio (o usuário simplesmente entra).
    elsif (existing = pending.find_by(email: email))
      existing.update(note: note)
    else
      # create (sem bang): e-mail malformado não estoura — só não registra.
      create(email: email, name: name, note: note)
    end
  end

  # Aprova o pedido (Q35): numa transação, cria a conta e dispara o convite Pull
  # (InvitationMailer.created — informativo, sem código; o magic-code nasce quando
  # a pessoa logar). Edge: se o e-mail JÁ virou conta (convite manual entre o
  # pedido e a aprovação), só marca approved — não recria a conta nem reenvia o
  # convite (a pessoa já foi avisada quando foi convidada). Só a partir de pending.
  def approve!
    ensure_pending!

    # A transação cobre SÓ a criação da conta + a marca approved (atomicidade: se
    # o create! estoura, o request continua pending). O enqueue do convite fica
    # FORA dela e SÓ acontece se a transação commitou e um user novo foi criado.
    #
    # Por que fora da transação: o job roda no solid_queue, que em produção vive
    # num BANCO separado (database: queue) — o worker não enxerga nossa transação
    # aberta e, como `enqueue_after_transaction_commit` é false, poderia pegar o
    # job antes do COMMIT e resolver o GlobalID pra um User ainda não visível
    # (RecordNotFound). Em dev o adapter é :inline (roda síncrono), o que também
    # não deve acontecer com a transação aberta. Enfileirar depois do commit evita
    # os dois. Edge preservado: e-mail que JÁ virou conta -> sem convite.
    created_user = nil

    transaction do
      if User.exists?(email: email)
        # Já é conta: só resolvemos o pedido, sem duplicar conta/convite.
        approved!
      else
        created_user = User.create!(email: email, name: name)
        approved!
      end
    end

    InvitationMailer.with(user: created_user).created.deliver_later if created_user
  end

  # Recusa o pedido (Q35): SILENCIOSO — nenhum e-mail, nenhuma conta. Só a partir
  # de pending.
  def reject!
    ensure_pending!
    rejected!
  end

  private
    def ensure_pending!
      raise InvalidTransition, I18n.t("activerecord.errors.models.access_request.invalid_transition", status: status) unless pending?
    end
end
