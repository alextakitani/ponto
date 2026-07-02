# Soft delete via coluna `archived_at` (Q7). Arquivar preserva o histórico (entries
# que apontam pra entidade continuam válidos); só o hard-delete some de vez, e esse
# fica pras entidades sem entries — decisão de cada model, não deste concern.
#
# SEM `default_scope` (decisão explícita Q7): scope global esconde dados e vaza em
# joins/counts de formas difíceis de auditar. Aqui os scopes são EXPLÍCITOS —
# `active`/`archived` — e a query normal enxerga tudo, forçando quem consulta a
# escolher.
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }
  end

  def archive!
    # Idempotente: já arquivado mantém o carimbo original (a data de arquivamento é
    # a PRIMEIRA, não a última tentativa).
    update!(archived_at: Time.current) unless archived?
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def active?
    !archived?
  end
end
