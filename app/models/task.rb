# Tarefa do projeto (Fatia 2.3) — sub-bucket do Project (Q1). Isolamento DIRETO por
# `user_id` (Q23) além do `project_id`. Nome ÚNICO POR PROJETO (Q44 — a mesma "Design"
# pode existir em projetos diferentes). Estrutura (não histórico): some junto com o
# projeto (dependent: :destroy no Project).
class Task < ApplicationRecord
  belongs_to :user
  belongs_to :project

  include Archivable

  # Criptografia at rest (Q25c). deterministic pela unicidade por projeto (o índice
  # único bate no ciphertext), como Client/Project.
  encrypts :name, deterministic: true

  validates :name, presence: true
  # Nome ÚNICO por PROJETO, incluindo arquivados (Q44). UX de colisão no form inline.
  validates :name, uniqueness: { scope: :project_id, message: :taken }
  validate :project_belongs_to_user

  # A colisão de nome bateu numa task ARQUIVADA do mesmo projeto? A UI troca o erro
  # cru pela dica de desarquivar (Q44), como Client/Project.
  def name_conflicts_with_archived?
    errors.include?(:name) &&
      project&.tasks&.archived&.exists?(name: name)
  end

  private
    # O projeto tem que ser do MESMO user (isolamento Q23) — a task não pode "pular"
    # pra um projeto de outra conta mandando o id cru. Compara user_id sem carregar o
    # projeto alheio inteiro.
    def project_belongs_to_user
      if project && project.user_id != user_id
        errors.add(:project, :not_owned)
      end
    end
end
