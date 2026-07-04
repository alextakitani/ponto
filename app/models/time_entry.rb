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

  encrypts :description
  monetize :rate_cents, allow_nil: true, with_model_currency: :currency

  validates :started_at, presence: true
  validates :currency, presence: true
  validate :ended_at_after_started_at
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
      update!(ended_at: timestamp)
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
      update!(ended_at: cut)
      second.save!
      second
    end
  end

  private
    def ended_at_after_started_at
      if ended_at.present? && started_at.present? && ended_at <= started_at
        errors.add(:ended_at, :after_started_at)
      end
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
