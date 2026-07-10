require "json"

# Portabilidade JSON — IMPORT (Q26/Q72). Lê um documento gerado pelo Account::Export
# e reconstrói a bolha do `user` numa transação. Só roda em bolha VAZIA (Q72). Os IDs
# ORIGINAIS do arquivo são só referências: cada entidade nasce com id novo e um mapa
# `id_antigo -> record_novo` remapeia as FKs (project_id/task_id/client_id/tag_id).
#
# PONTO CRÍTICO: os snapshots rate/currency do TimeEntry entram COMO ESTÃO (Q72) —
# `skip_rate_snapshot` desliga o recálculo a partir do projeto atual, senão o
# round-trip revalorizaria o histórico. `allow_overlap` deixa passar sobreposições
# preexistentes (o import preserva o histórico externo, não o valida).
class Account::Import
  SCHEMA_VERSION = 1

  Error = Class.new(StandardError)

  Result = Data.define(
    :clients_created,
    :projects_created,
    :tasks_created,
    :tags_created,
    :time_entries_created
  )

  def initialize(user:, io:)
    @user = user
    @io = io
  end

  def run!
    document = parse!
    validate_schema!(document)

    ActiveRecord::Base.transaction do
      ensure_empty_bubble!

      # Suprime broadcasts individuais por entry durante a carga em lote — evita a
      # "broadcast storm" de N refreshes; dispara UM refresh único ao final (mesmo
      # mecanismo do Clockify::Import).
      TimeEntry.suppressing_turbo_broadcasts do
        clients = create_clients(document.fetch("clients", []))
        projects = create_projects(document.fetch("projects", []), clients)
        tasks = create_tasks(document.fetch("tasks", []), projects)
        tags = create_tags(document.fetch("tags", []))
        entries = create_time_entries(document.fetch("time_entries", []), projects, tasks)
        create_taggings(document.fetch("taggings", []), tags, entries)

        restore_preferences(document["user"])

        @result = Result.new(
          clients.size,
          projects.size,
          tasks.size,
          tags.size,
          entries.size
        )
      end
    end

    Turbo::StreamsChannel.broadcast_refresh_to(user)

    @result
  end

  private
    attr_reader :user, :io

    def parse!
      JSON.parse(io.to_s)
    rescue JSON::ParserError
      raise Error, I18n.t("account.data_imports.errors.malformed_json")
    end

    def validate_schema!(document)
      unless document.is_a?(Hash) && document["schema_version"] == SCHEMA_VERSION
        raise Error, I18n.t("account.data_imports.errors.unsupported_schema_version", version: SCHEMA_VERSION)
      end
    end

    def ensure_empty_bubble!
      raise Error, I18n.t("account.data_imports.errors.non_empty_bubble") unless user.empty_bubble?
    end

    # Cada método devolve um mapa `id_do_arquivo -> record_novo`, base do remapeamento
    # de FK das entidades seguintes.
    def create_clients(rows)
      rows.to_h do |row|
        client = user.clients.create!(
          name: row["name"],
          note: row["note"],
          rate_cents: row["rate_cents"],
          currency: row["currency"],
          archived_at: row["archived_at"]
        )
        [ row["id"], client ]
      end
    end

    def create_projects(rows, clients)
      rows.to_h do |row|
        project = user.projects.create!(
          name: row["name"],
          color: row["color"],
          client: clients[row["client_id"]],
          rate_cents: row["rate_cents"],
          archived_at: row["archived_at"]
        )
        [ row["id"], project ]
      end
    end

    def create_tasks(rows, projects)
      rows.to_h do |row|
        task = user.tasks.create!(
          name: row["name"],
          project: projects.fetch(row["project_id"]),
          archived_at: row["archived_at"]
        )
        [ row["id"], task ]
      end
    end

    def create_tags(rows)
      rows.to_h do |row|
        tag = user.tags.create!(
          name: row["name"],
          archived_at: row["archived_at"]
        )
        [ row["id"], tag ]
      end
    end

    def create_time_entries(rows, projects, tasks)
      rows.to_h do |row|
        entry = user.time_entries.build(
          project: projects[row["project_id"]],
          task: tasks[row["task_id"]],
          description: row["description"],
          started_at: row["started_at"],
          ended_at: row["ended_at"],
          rate_cents: row["rate_cents"],
          currency: row["currency"],
          billable: row["billable"]
        )
        # Q72: preserva o snapshot do arquivo e o histórico sobreposto — nada de
        # recalcular a rate nem barrar por overlap.
        entry.skip_rate_snapshot = true
        entry.allow_overlap = true
        entry.save!

        [ row["id"], entry ]
      end
    end

    def create_taggings(rows, tags, entries)
      rows.each do |row|
        Tagging.create!(
          tag: tags.fetch(row["tag_id"]),
          time_entry: entries.fetch(row["time_entry_id"])
        )
      end
    end

    # Restaura só preferências (é migração de instância) — nunca email/admin. O
    # default_project_id não viaja no arquivo (fica nil): quem quiser reescolhe.
    def restore_preferences(attributes)
      return if attributes.blank?

      user.update!(
        name: attributes["name"],
        time_zone: attributes["time_zone"],
        locale: attributes["locale"],
        theme: attributes["theme"],
        accent: attributes["accent"],
        export_locale: attributes["export_locale"]
      )
    end
end
