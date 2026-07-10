# Portabilidade JSON — EXPORT (Q26/Q72). Serializa a bolha inteira do `user` (Q23)
# num único documento com `schema_version` e um array por entidade. Os IDs ORIGINAIS
# viajam como referências internas; o importador (Account::Import) os remapeia.
#
# Só ESCALARES no JSON — NUNCA um objeto Money cru (viraria hash gigante): dinheiro
# sai como `rate_cents` (int) + `currency` (string), decisão Q11/Q20. Datas em ISO8601
# UTC. Tudo escopado por `user.` (nada de outra conta vaza — isolamento Q23).
class Account::Export
  SCHEMA_VERSION = 1

  def initialize(user:)
    @user = user
  end

  def filename
    "ponto-export-#{Date.current.iso8601}.json"
  end

  def to_json(*)
    JSON.generate(as_json)
  end

  # Monta o Hash do documento. Determinístico (ordena por id) pra o round-trip e os
  # testes ficarem estáveis.
  def as_json(*)
    {
      schema_version: SCHEMA_VERSION,
      user: user_attributes,
      clients: clients,
      projects: projects,
      tasks: tasks,
      tags: tags,
      time_entries: time_entries,
      taggings: taggings
    }
  end

  private
    attr_reader :user

    # Só preferências (nome/fuso/tema/acento/locale). Credenciais e papel NÃO entram:
    # email/admin/suspended_at são identidade e operação, não dado portável (Q72).
    def user_attributes
      {
        name: user.name,
        time_zone: user.time_zone,
        locale: user.locale,
        theme: user.theme,
        accent: user.accent,
        export_locale: user.export_locale
      }
    end

    def clients
      user.clients.order(:id).map do |client|
        {
          id: client.id,
          name: client.name,
          note: client.note,
          rate_cents: client.rate_cents,
          currency: client.currency,
          archived_at: iso8601(client.archived_at)
        }
      end
    end

    def projects
      user.projects.order(:id).map do |project|
        {
          id: project.id,
          name: project.name,
          color: project.color,
          client_id: project.client_id,
          rate_cents: project.rate_cents,
          archived_at: iso8601(project.archived_at)
        }
      end
    end

    def tasks
      user.tasks.order(:id).map do |task|
        {
          id: task.id,
          name: task.name,
          project_id: task.project_id,
          archived_at: iso8601(task.archived_at)
        }
      end
    end

    def tags
      user.tags.order(:id).map do |tag|
        {
          id: tag.id,
          name: tag.name,
          archived_at: iso8601(tag.archived_at)
        }
      end
    end

    def time_entries
      user.time_entries.order(:id).map do |entry|
        {
          id: entry.id,
          project_id: entry.project_id,
          task_id: entry.task_id,
          description: entry.description,
          started_at: iso8601(entry.started_at),
          ended_at: iso8601(entry.ended_at),
          rate_cents: entry.rate_cents,
          currency: entry.currency,
          billable: entry.billable
        }
      end
    end

    def taggings
      Tagging.where(time_entry_id: user.time_entries.select(:id)).order(:id).map do |tagging|
        {
          id: tagging.id,
          tag_id: tagging.tag_id,
          time_entry_id: tagging.time_entry_id
        }
      end
    end

    def iso8601(time)
      time&.utc&.iso8601
    end
end
