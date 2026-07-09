# Sessão atômica de trabalho (Fatia 3.1). Vive na bolha do `user` (Q23) e carrega um
# snapshot histórico da rate/moeda efetiva do projeto no momento do save (Q10/Q11).
# Pode rodar (`ended_at` nil) ou estar finalizada; o timer único por user é garantido
# no BANCO pelo índice parcial e tratado na API no controller.
class TimeEntry < ApplicationRecord
  DEFAULT_CURRENCY = "BRL"

  belongs_to :user
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  # Notifica TODAS as abas do mesmo user quando o timer ou entries mudam por qualquer
  # caminho (web, API com Bearer, CLI). Stream escopado por user — isolamento Q23.
  broadcasts_refreshes_to :user

  # Escape para caminhos internos que podem conviver com sobreposição: importador,
  # stop_at e split.
  attr_accessor :allow_overlap

  monetize :rate_cents, allow_nil: true, with_model_currency: :currency

  validates :started_at, presence: true
  validates :currency, presence: true
  validate :ended_at_after_started_at
  validate :no_overlap, if: :validate_overlap?
  validate :project_belongs_to_user
  validate :task_belongs_to_user
  validate :task_matches_project

  before_validation :clear_task_when_project_changes
  before_validation :snapshot_project_rate
  before_validation :default_billable_from_rate, on: :create

  def billable=(value)
    @billable_explicitly_assigned = true
    super
  end

  def duration_seconds
    if ended_at?
      (ended_at - started_at).to_i
    end
  end

  def billable_amount
    if ended_at? && billable? && !rate_cents.nil?
      Money.new(billable_amount_cents, currency)
    end
  end

  def stop_at(timestamp)
    if timestamp == started_at
      destroy
    else
      # Q49c/Q22: parar timer é invariante operacional; nunca deve falhar por overlap.
      self.allow_overlap = true
      update!(ended_at: timestamp)
    end
  end

  def overlapping_entries
    return TimeEntry.none if user_id.blank? || started_at.blank?

    # Entry rodando (ended_at nil) cobre [started_at, ∞): qualquer entry finalizada
    # cujo fim venha depois do nosso start se sobrepõe. Sem isto, editar o started_at
    # de um timer contornava a validação (a sobreposição do log entrava aqui — a
    # 10346 teve o start arrastado 55s pra dentro da 10345 finalizada).
    scope = user.time_entries.where.not(id: id).where.not(ended_at: nil)
    if ended_at.present?
      scope.where("? < time_entries.ended_at AND time_entries.started_at < ?", started_at, ended_at)
    else
      scope.where("? < time_entries.ended_at", started_at)
    end
  end

  def attributes_for_restart
    slice(:project_id, :task_id, :description, :billable)
  end

  # Quebra este entry FINALIZADO em dois no `cut` (Q48). A metade A (self) fica
  # started_at..cut; a metade B nasce cópia FIEL (descrição/projeto/task/billable)
  # cobrindo cut..ended_at original. Cada metade re-resolve/congela SEU snapshot: B é
  # um record novo, então o `before_validation :snapshot_project_rate` recalcula a rate
  # a partir do project (não copia cru de A). Corte estritamente ENTRE started_at e
  # ended_at (Q15c: nada de duração-zero); só entry finalizado (rodando não pode).
  # Atômico: encurta A + cria B numa transação (rollback total se algo falhar).
  # Retorna a metade B.
  def split_at(cut)
    raise ArgumentError, I18n.t("activerecord.errors.models.time_entry.split.finished_only") unless ended_at?
    unless cut > started_at && cut < ended_at
      raise ArgumentError, I18n.t("activerecord.errors.models.time_entry.split.cut_between")
    end

    original_ended_at = ended_at
    transaction do
      second = user.time_entries.build(
        project_id: project_id,
        task_id: task_id,
        description: description,
        billable: billable,
        started_at: cut,
        ended_at: original_ended_at
      )
      # Q49c/Q22: split produz metades internas; overlap pré-existente não bloqueia.
      self.allow_overlap = true
      second.allow_overlap = true
      update!(ended_at: cut)
      second.save!
      second
    end
  end

  # Filtro por intervalo sobre `started_at` (usado no GET /time_entries JSON): a
  # entry pertence inteira ao instante do seu `started_at` (Q6, sem fatiar). `until`
  # é FIM EXCLUSIVO (`<`) de propósito — a fronteira do próximo período (ex.: a
  # segunda-feira 00:00 seguinte) não entra na janela. Compara em UTC; o argumento
  # já carrega seu offset quando vem ISO 8601.
  scope :started_since, ->(time) { where(started_at: time..) }
  scope :started_before, ->(time) { where(started_at: ...time) }

  private
    def ended_at_after_started_at
      if ended_at.present? && started_at.present? && ended_at <= started_at
        errors.add(:ended_at, :after_started_at)
      end
    end

    def validate_overlap?
      # Roda também com a entry rodando (ended_at nil): mudar o started_at de um
      # timer ou criar um timer sobreposto a uma finalizada devem ser barrados.
      (started_at_changed? || ended_at_changed?) && !allow_overlap
    end

    def no_overlap
      overlapping = overlapping_entries.order(:started_at).first
      return unless overlapping

      errors.add(:started_at, :overlap, range: overlap_range(overlapping))
    end

    def overlap_range(overlapping)
      zone = ActiveSupport::TimeZone[user.time_zone] || Time.zone
      started = overlapping.started_at.in_time_zone(zone).strftime("%H:%M")
      ended = overlapping.ended_at.in_time_zone(zone).strftime("%H:%M")
      "#{started} - #{ended}"
    end

    def project_belongs_to_user
      return unless project_id.present?

      unless Project.where(id: project_id, user_id: user_id).exists?
        errors.add(:project, :not_owned)
      end
    end

    def task_belongs_to_user
      return unless task_id.present?

      unless Task.joins(:project).where(tasks: { id: task_id, user_id: user_id }, projects: { user_id: user_id }).exists?
        errors.add(:task, :not_owned)
      end
    end

    def task_matches_project
      return unless task_id.present?

      if project_id.blank?
        errors.add(:task, :requires_project)
      elsif Task.where(id: task_id, project_id: project_id).none?
        errors.add(:task, :project_mismatch)
      end
    end

    def clear_task_when_project_changes
      if persisted? && will_save_change_to_project_id? && task_id.present? && task_project_id != project_id
        self.task_id = nil
      end
    end

    def snapshot_project_rate
      return unless new_record? || will_save_change_to_project_id?

      if project
        self.rate_cents = project.effective_rate_cents
        self.currency = project.effective_currency || DEFAULT_CURRENCY
      else
        self.rate_cents = nil
        self.currency = DEFAULT_CURRENCY
      end
    end

    def default_billable_from_rate
      return if @billable_explicitly_assigned

      self.billable = !rate_cents.nil?
    end

    def duration_in_hours
      BigDecimal(duration_seconds.to_s) / 3600
    end

    def billable_amount_cents
      (BigDecimal(rate_cents.to_s) * duration_in_hours).round(0, BigDecimal::ROUND_HALF_UP)
    end

    def task_project_id
      Task.where(id: task_id).pick(:project_id)
    end
end
