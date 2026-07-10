require "test_helper"

# Portabilidade JSON — IMPORT (Q26/Q72), fluxo HTTP. Upload síncrono numa conta vazia,
# guard de bolha cheia e tratamento de arquivo inválido.
class Account::DataImportsTest < ActionDispatch::IntegrationTest
  test "upload em conta vazia importa e redireciona pra home" do
    user = create_user(email: "importer@example.com", onboarded_at: nil)
    sign_in_as("importer@example.com", user: user)

    assert_difference -> { user.clients.count }, 1 do
      post account_data_import_path, params: {
        account_data_import: { file: upload(sample_document) }
      }
    end

    assert_redirected_to home_path
    assert_equal "Acme", user.clients.sole.name
    assert_equal 1, user.time_entries.count
    assert_equal 15000, user.time_entries.sole.rate_cents
  end

  test "GET new numa conta vazia mostra o form" do
    user = create_user(email: "new-import@example.com", onboarded_at: nil)
    sign_in_as("new-import@example.com", user: user)

    get new_account_data_import_path

    assert_response :success
    assert_select "input[type=file]", count: 1
  end

  test "GET new numa conta cheia bloqueia o form" do
    user = create_user(email: "full-new@example.com")
    user.clients.create!(name: "Existing")
    sign_in_as("full-new@example.com", user: user)

    get new_account_data_import_path

    assert_response :success
    assert_select "input[type=file]", count: 0
    assert_select "h2", I18n.t("account.data_imports.new.blocked.title")
  end

  test "upload numa conta cheia é recusado com alerta" do
    user = create_user(email: "full-import@example.com")
    user.clients.create!(name: "Existing")
    sign_in_as("full-import@example.com", user: user)

    assert_no_difference -> { user.clients.count } do
      post account_data_import_path, params: {
        account_data_import: { file: upload(sample_document) }
      }
    end

    assert_redirected_to new_account_data_import_path
    assert_equal I18n.t("account.data_imports.create.non_empty_bubble"), flash[:alert]
  end

  test "arquivo JSON inválido re-renderiza com erro" do
    user = create_user(email: "bad-import@example.com", onboarded_at: nil)
    sign_in_as("bad-import@example.com", user: user)

    post account_data_import_path, params: {
      account_data_import: { file: upload("{ não é json") }
    }

    assert_response :unprocessable_entity
    assert_select ".form-errors", I18n.t("account.data_imports.errors.malformed_json")
    assert_equal 0, user.clients.count
  end

  test "sem arquivo re-renderiza com erro" do
    user = create_user(email: "no-file@example.com", onboarded_at: nil)
    sign_in_as("no-file@example.com", user: user)

    post account_data_import_path, params: { account_data_import: {} }

    assert_response :unprocessable_entity
    assert_select ".form-errors", I18n.t("account.data_imports.new.form.file_blank")
  end

  private
    def sample_document
      JSON.generate(
        schema_version: 1,
        user: { name: nil, time_zone: "America/Sao_Paulo", locale: nil, theme: "system", accent: "teal", export_locale: nil },
        clients: [ { id: 1, name: "Acme", note: nil, rate_cents: 12000, currency: "EUR", archived_at: nil } ],
        projects: [ { id: 10, name: "Site", color: "#1e66f5", client_id: 1, rate_cents: 15000, archived_at: nil } ],
        tasks: [],
        tags: [],
        time_entries: [ {
          id: 100, project_id: 10, task_id: nil, description: "work",
          started_at: "2026-07-10T12:00:00Z", ended_at: "2026-07-10T13:00:00Z",
          rate_cents: 15000, currency: "EUR", billable: true
        } ],
        taggings: []
      )
    end

    def upload(content, filename = "ponto-export.json")
      tempfile = Tempfile.new([ File.basename(filename, ".json"), ".json" ])
      tempfile.binmode
      tempfile.write(content)
      tempfile.rewind
      Rack::Test::UploadedFile.new(tempfile.path, "application/json", original_filename: filename)
    end
end
