require "test_helper"

# Portabilidade JSON (Q26/Q72): o export monta a bolha inteira do user num único
# documento com escalares (nada de Money cru). Testa o QUE nós montamos — escopo por
# user (Q23), escalares rate_cents/currency, datas ISO8601, determinismo — não o
# JSON.generate do Ruby.
class Account::ExportTest < ActiveSupport::TestCase
  test "monta o documento com schema_version e um array por entidade" do
    user = create_user
    seed_bubble(user)

    document = Account::Export.new(user: user).as_json

    assert_equal 1, document[:schema_version]
    assert_equal 1, document[:clients].size
    assert_equal 1, document[:projects].size
    assert_equal 1, document[:tasks].size
    assert_equal 1, document[:tags].size
    assert_equal 1, document[:time_entries].size
    assert_equal 1, document[:taggings].size
  end

  test "exporta só as preferências do user (sem email/admin)" do
    user = create_user(name: "Alex", time_zone: "America/Sao_Paulo", export_locale: "pt-BR")

    document = Account::Export.new(user: user).as_json

    assert_equal "Alex", document[:user][:name]
    assert_equal "America/Sao_Paulo", document[:user][:time_zone]
    assert_equal "pt-BR", document[:user][:export_locale]
    assert_not document[:user].key?(:email)
    assert_not document[:user].key?(:admin)
    assert_not document[:user].key?(:id)
  end

  test "escalares de dinheiro (rate_cents int + currency string), sem Money cru" do
    user = create_user
    client = user.clients.create!(name: "Acme", rate_cents: 12000, currency: "EUR")
    project = user.projects.create!(name: "Site", client: client, rate_cents: 15000)

    document = Account::Export.new(user: user).as_json

    exported_client = document[:clients].first
    assert_equal 12000, exported_client[:rate_cents]
    assert_equal "EUR", exported_client[:currency]
    assert_kind_of Integer, exported_client[:rate_cents]

    exported_project = document[:projects].first
    assert_equal 15000, exported_project[:rate_cents]

    exported_entry = document[:time_entries].first if document[:time_entries].any?
    assert_nil exported_entry
  end

  test "datas em ISO8601 UTC" do
    user = create_user
    started = Time.utc(2026, 7, 10, 12, 0, 0)
    ended = Time.utc(2026, 7, 10, 13, 0, 0)
    user.time_entries.create!(started_at: started, ended_at: ended, allow_overlap: true)

    entry = Account::Export.new(user: user).as_json[:time_entries].first

    assert_equal "2026-07-10T12:00:00Z", entry[:started_at]
    assert_equal "2026-07-10T13:00:00Z", entry[:ended_at]
  end

  test "entry rodando exporta ended_at nulo" do
    user = create_user
    user.time_entries.create!(started_at: Time.utc(2026, 7, 10, 12), allow_overlap: true)

    entry = Account::Export.new(user: user).as_json[:time_entries].first

    assert_nil entry[:ended_at]
  end

  test "isolamento Q23: dados de outro user não vazam" do
    owner = create_user(email: "owner@example.com")
    other = create_user(email: "other@example.com")
    owner.clients.create!(name: "Mine")
    other.clients.create!(name: "Theirs")

    document = Account::Export.new(user: owner).as_json

    assert_equal 1, document[:clients].size
    assert_equal "Mine", document[:clients].first[:name]
  end

  test "ordenação determinística por id" do
    user = create_user
    user.tags.create!(name: "beta")
    user.tags.create!(name: "alfa")

    ids = Account::Export.new(user: user).as_json[:tags].pluck(:id)

    assert_equal ids.sort, ids
  end

  test "filename carrega a data de hoje" do
    export = Account::Export.new(user: create_user)

    assert_equal "ponto-export-#{Date.current.iso8601}.json", export.filename
  end

  private
    def seed_bubble(user)
      client = user.clients.create!(name: "Acme", rate_cents: 10000, currency: "BRL")
      project = user.projects.create!(name: "Site", client: client)
      task = user.tasks.create!(name: "Dev", project: project)
      tag = user.tags.create!(name: "urgent")
      entry = user.time_entries.create!(
        project: project, task: task, description: "work",
        started_at: Time.utc(2026, 7, 10, 12), ended_at: Time.utc(2026, 7, 10, 13),
        allow_overlap: true
      )
      Tagging.create!(tag: tag, time_entry: entry)
    end
end
