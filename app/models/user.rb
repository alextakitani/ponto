class User < ApplicationRecord
  # Erro de domínio (Q34c): o sistema nunca pode ficar sem ≥1 admin ATIVO.
  LastAdminError = Class.new(StandardError)

  has_many :sessions, dependent: :destroy
  has_many :sign_in_codes, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  # Domínio isolado por user (Q23). dependent: :destroy leva a bolha junto na
  # deleção da conta (destroy_completely — Q33).
  has_many :clients, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  # `tasks` também pende direto do user (isolamento DIRETO Q23 — a Task carrega
  # user_id além de project_id), pra a deleção da conta levar a bolha inteira.
  has_many :tasks, dependent: :destroy

  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Invariante ≥1 admin ATIVO (Q34c). Admin suspenso NÃO conta como ativo.
  # - rebaixar (admin: true -> false) o último admin ativo: falha na validação;
  # - suspender (suspended_at nil -> presente) o último admin ativo: idem, na
  #   validação — barra até o update cru (sem passar pelo suspend!);
  # - destruir o último admin ativo: abortado no before_destroy.
  scope :active_admins, -> { where(admin: true, suspended_at: nil) }

  # Pré-carrega o COUNT de sessions por conta numa query só (mata o N+1 do
  # invited?/status na listagem do admin). Expõe a coluna virtual sessions_count
  # que o #invited? aproveita quando presente.
  scope :with_sessions_count, -> {
    left_joins(:sessions)
      .select("users.*, COUNT(sessions.id) AS sessions_count")
      .group("users.id")
  }

  validate :must_keep_one_active_admin, if: :demoting_last_active_admin?
  validate :must_keep_one_active_admin_on_suspend, if: :suspending_last_active_admin?
  before_destroy :must_keep_one_active_admin_on_destroy

  # Bootstrap do 1º admin (Q37): só com o banco VAZIO e o e-mail batendo com
  # ENV["ADMIN_EMAIL"] (presente e não-vazio) criamos a conta — já como admin.
  # Com qualquer conta existente, ADMIN_EMAIL fica inerte (devolve nil).
  def self.bootstrap_admin(email)
    return unless none?

    admin_email = normalize_value_for(:email, ENV["ADMIN_EMAIL"])
    return if admin_email.blank? || admin_email != email

    create!(email: email, admin: true)
  end

  # Aviso de operador (Q38): sem nenhuma conta E sem ADMIN_EMAIL configurado, o app
  # não tem como fazer o bootstrap do 1º admin. NÃO caímos no fallback "1º a logar
  # vira admin" — pedimos que o operador defina a variável de ambiente.
  def self.bootstrap_blocked?
    none? && normalize_value_for(:email, ENV["ADMIN_EMAIL"]).blank?
  end

  # Bearer escopado por método HTTP (decisões §3, padrão fizzy).
  def self.find_by_permissable_access_token(token, method:)
    access_token = AccessToken.find_by(token: token)
    return unless access_token&.allows?(method)

    access_token.touch_usage!
    access_token.user
  end

  # Suspensão (Q34): estado por timestamp (soft-state do projeto). Suspender NÃO
  # destrói sessões — o gate no Authentication barra a cada request; reativar
  # restaura o acesso na hora.
  def suspended?
    suspended_at.present?
  end

  # Status derivado pra listagem do admin (Q31) — SEM coluna nova. Suspenso tem
  # prioridade; senão, "convidado" (nunca entrou) vs "ativo" (já entrou).
  def status
    if suspended?
      :suspended
    elsif invited?
      :invited
    else
      :active
    end
  end

  # "Convidado" = criado mas nunca entrou. Também gate do "reenviar convite" (Q31).
  # Se a query trouxe o sessions_count (scope with_sessions_count), usamos ele e
  # evitamos o COUNT por linha; senão, caímos no sessions.none? de sempre.
  def invited?
    if has_attribute?(:sessions_count)
      self[:sessions_count].to_i.zero?
    else
      sessions.none?
    end
  end

  # A invariante ≥1 admin ativo vive na validação (barra até update cru); aqui
  # só reembrulhamos o erro no LastAdminError pela ergonomia da API.
  def suspend!
    update!(suspended_at: Time.current)
  rescue ActiveRecord::RecordInvalid
    raise LastAdminError, "não é possível suspender o último admin ativo"
  end

  def reactivate!
    update!(suspended_at: nil)
  end

  # Deletar conta = apagar a BOLHA inteira do usuário (Q33/Q33a). Hoje a bolha é
  # só o auth: sessions/sign_in_codes/access_tokens saem pelos `dependent: :destroy`
  # das associações acima. A fatia de domínio (Clients/Projects/TimeEntries…)
  # ESTENDE este método pra levar junto os dados de domínio no mesmo destroy.
  # O before_destroy (invariante ≥1 admin ativo) barra e devolve false, como todo
  # `destroy` do Active Record.
  def destroy_completely
    destroy
  end

  # Emite um código de 6 dígitos, manda por e-mail e devolve o SignInCode
  # (em dev o controller usa o código em claro p/ servir via flash/header).
  #
  # O código em claro vai como argumento pro mailer (não via record): deliver_later
  # serializa o SignInCode e o recarrega no job, perdendo o atributo transiente.
  def send_sign_in_code
    sign_in_codes.create!.tap do |sign_in_code|
      SignInMailer.with(user: self, code: sign_in_code.code).code.deliver_later
    end
  end

  private

  # Sou o ÚNICO admin ativo, olhando o estado PERSISTIDO (não o in-memory, que
  # pode estar sujo por um update que falhou antes)? Uso interno das guardas Q34c.
  def last_active_admin?
    persisted? &&
      self.class.active_admins.exists?(id) &&
      no_other_active_admin?
  end

  def no_other_active_admin?
    self.class.active_admins.where.not(id: id).none?
  end

  # Só valida na transição admin true -> false (rebaixamento).
  def demoting_last_active_admin?
    persisted? && admin_changed? && admin_was && !admin
  end

  # Só valida na transição suspended_at nil -> presente de um admin (suspensão).
  def suspending_last_active_admin?
    persisted? && admin? && suspended_at_changed? && suspended_at_was.nil? && suspended_at.present?
  end

  def must_keep_one_active_admin
    # Se não sobra nenhum OUTRO admin ativo, o rebaixamento deixaria o sistema
    # sem admin ativo.
    return unless no_other_active_admin?

    errors.add(:admin, "não pode rebaixar o último admin ativo")
  end

  def must_keep_one_active_admin_on_suspend
    # Se não sobra nenhum OUTRO admin ativo, a suspensão deixaria o sistema sem
    # admin ativo.
    return unless no_other_active_admin?

    errors.add(:suspended_at, "não pode suspender o último admin ativo")
  end

  def must_keep_one_active_admin_on_destroy
    return unless last_active_admin?

    errors.add(:base, "não é possível remover o último admin ativo")
    throw :abort
  end
end
