require "test_helper"

# Portabilidade JSON — IMPORT (Q26/Q72). O import só roda em bolha VAZIA (Q72),
# remapeia os IDs originais e preserva os snapshots rate/currency COMO ESTÃO (não
# recalcula do projeto). Testa a nossa lógica: round-trip, guard de bolha vazia,
# validação de schema, remapeamento de FK, restauração de archived_at, isolamento Q23.
class Account::ImportTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  test "round-trip: export de um user e import noutro batem contagens e campos" do
    source = create_user(email: "source@example.com", name: "Alex", time_zone: "America/Bahia", export_locale: "en")
    seed_full_bubble(source)
    document = Account::Export.new(user: source).to_json

    target = create_user(email: "target@example.com")
    result = Account::Import.new(user: target, io: document).run!

    assert_equal 1, result.clients_created
    assert_equal 1, result.projects_created
    assert_equal 1, result.tasks_created
    assert_equal 2, result.tags_created
    assert_equal 1, result.time_entries_created

    assert_equal 1, target.clients.count
    assert_equal 1, target.projects.count
    assert_equal 1, target.tasks.count
    assert_equal 2, target.tags.count
    assert_equal 1, target.time_entries.count

    client = target.clients.sole
    assert_equal "Acme", client.name
    assert_equal 12000, client.rate_cents
    assert_equal "EUR", client.currency

    project = target.projects.sole
    assert_equal client, project.client
    assert_equal 15000, project.rate_cents
  end

  test "restaura preferências do user (name/time_zone/export_locale) sem tocar email/admin" do
    source = create_user(email: "src2@example.com", name: "Alex Prefs", time_zone: "America/Bahia", export_locale: "en")
    source.clients.create!(name: "Acme")
    document = Account::Export.new(user: source).to_json

    target = create_user(email: "tgt2@example.com", admin: true)
    Account::Import.new(user: target, io: document).run!
    target.reload

    assert_equal "Alex Prefs", target.name
    assert_equal "America/Bahia", target.time_zone
    assert_equal "en", target.export_locale
    assert_equal "tgt2@example.com", target.email
    assert target.admin?
  end

  test "PONTO CRÍTICO: preserva o snapshot rate/currency divergente do projeto atual" do
    document = document_with(
      clients: [ { id: 1, name: "Acme", rate_cents: 30000, currency: "EUR", archived_at: nil } ],
      projects: [ { id: 10, name: "Site", color: "#1e66f5", client_id: 1, rate_cents: 30000, archived_at: nil } ],
      time_entries: [ {
        id: 100, project_id: 10, task_id: nil, description: "legacy",
        started_at: "2026-01-01T12:00:00Z", ended_at: "2026-01-01T13:00:00Z",
        rate_cents: 15000, currency: "USD", billable: true
      } ]
    )

    target = create_user(email: "snap@example.com")
    Account::Import.new(user: target, io: document).run!

    entry = target.time_entries.sole
    assert_equal 15000, entry.rate_cents
    assert_equal "USD", entry.currency
    assert entry.billable?
  end

  test "entry NÃO faturável sobrevive ao import (billable false explícito)" do
    document = document_with(
      time_entries: [ {
        id: 100, project_id: nil, task_id: nil, description: "livre",
        started_at: "2026-01-01T12:00:00Z", ended_at: "2026-01-01T13:00:00Z",
        rate_cents: 5000, currency: "BRL", billable: false
      } ]
    )

    target = create_user(email: "nb@example.com")
    Account::Import.new(user: target, io: document).run!

    assert_not target.time_entries.sole.billable?
  end

  test "remapeia FKs project_id/task_id/tag_id pros novos records" do
    document = document_with(
      clients: [ { id: 1, name: "Acme", rate_cents: nil, currency: "BRL", archived_at: nil } ],
      projects: [ { id: 10, name: "Site", color: "#1e66f5", client_id: 1, rate_cents: nil, archived_at: nil } ],
      tasks: [ { id: 20, name: "Dev", project_id: 10, archived_at: nil } ],
      tags: [ { id: 30, name: "urgent", archived_at: nil } ],
      time_entries: [ {
        id: 100, project_id: 10, task_id: 20, description: "x",
        started_at: "2026-01-01T12:00:00Z", ended_at: "2026-01-01T13:00:00Z",
        rate_cents: nil, currency: "BRL", billable: false
      } ],
      taggings: [ { id: 200, tag_id: 30, time_entry_id: 100 } ]
    )

    target = create_user(email: "fk@example.com")
    Account::Import.new(user: target, io: document).run!

    entry = target.time_entries.sole
    project = target.projects.sole
    task = target.tasks.sole
    tag = target.tags.sole

    assert_equal project.id, entry.project_id
    assert_equal task.id, entry.task_id
    assert_equal project.id, task.project_id
    assert_equal [ tag.id ], entry.tags.pluck(:id)
    # Os novos IDs não coincidem com os originais do arquivo (remapeamento real).
    assert_not_equal 10, entry.project_id
  end

  test "restaura archived_at das entidades" do
    document = document_with(
      clients: [ { id: 1, name: "Old", rate_cents: nil, currency: "BRL", archived_at: "2025-01-01T00:00:00Z" } ]
    )

    target = create_user(email: "arch@example.com")
    Account::Import.new(user: target, io: document).run!

    assert target.clients.sole.archived?
  end

  test "guard: bolha não-vazia levanta erro e não escreve nada" do
    document = document_with(clients: [ { id: 1, name: "Acme", rate_cents: nil, currency: "BRL", archived_at: nil } ])
    target = create_user(email: "full@example.com")
    target.clients.create!(name: "Existing")

    assert_raises(Account::Import::Error) do
      Account::Import.new(user: target, io: document).run!
    end

    assert_equal 1, target.clients.count
  end

  test "schema_version divergente levanta erro claro" do
    document = JSON.generate({ schema_version: 99, clients: [], projects: [], tasks: [], tags: [], time_entries: [], taggings: [] })
    target = create_user(email: "ver@example.com")

    error = assert_raises(Account::Import::Error) do
      Account::Import.new(user: target, io: document).run!
    end
    assert_match(/version|versão/i, error.message)
  end

  test "JSON malformado levanta erro" do
    target = create_user(email: "malformed@example.com")

    assert_raises(Account::Import::Error) do
      Account::Import.new(user: target, io: "{ isto não é json").run!
    end
  end

  test "rollback: erro no meio não deixa registros parciais" do
    # tag_id inexistente na tagging força uma falha depois de criar catálogo/entries.
    document = document_with(
      clients: [ { id: 1, name: "Acme", rate_cents: nil, currency: "BRL", archived_at: nil } ],
      time_entries: [ {
        id: 100, project_id: nil, task_id: nil, description: "x",
        started_at: "2026-01-01T12:00:00Z", ended_at: "2026-01-01T13:00:00Z",
        rate_cents: nil, currency: "BRL", billable: false
      } ],
      taggings: [ { id: 200, tag_id: 999, time_entry_id: 100 } ]
    )

    target = create_user(email: "rollback@example.com")

    assert_raises(StandardError) do
      Account::Import.new(user: target, io: document).run!
    end

    assert_equal 0, target.clients.count
    assert_equal 0, target.time_entries.count
  end

  private
    def seed_full_bubble(user)
      client = user.clients.create!(name: "Acme", rate_cents: 12000, currency: "EUR")
      project = user.projects.create!(name: "Site", client: client, rate_cents: 15000)
      task = user.tasks.create!(name: "Dev", project: project)
      first_tag = user.tags.create!(name: "urgent")
      second_tag = user.tags.create!(name: "later")
      entry = user.time_entries.create!(
        project: project, task: task, description: "work",
        started_at: Time.utc(2026, 7, 10, 12), ended_at: Time.utc(2026, 7, 10, 13),
        allow_overlap: true
      )
      Tagging.create!(tag: first_tag, time_entry: entry)
      Tagging.create!(tag: second_tag, time_entry: entry)
    end

    # Monta um documento JSON mínimo válido, mesclando os arrays passados.
    def document_with(**entities)
      base = {
        schema_version: 1,
        user: { name: nil, time_zone: "America/Sao_Paulo", locale: nil, theme: "system", accent: "teal", export_locale: nil },
        clients: [], projects: [], tasks: [], tags: [], time_entries: [], taggings: []
      }
      JSON.generate(base.merge(entities))
    end
end
