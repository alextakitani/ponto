require "test_helper"

# Gaps de Bearer fora do CRUD principal: archivals agora respondem JSON, e export
# .csv/.xlsx entra no mesmo gate de AccessToken sem abrir HTML.
class BearerArchivalsAndExportsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(email: "ext@example.com")
    @read = @user.access_tokens.create!(permission: "read")
    @write = @user.access_tokens.create!(permission: "write")
  end

  test "POST e DELETE archival de client via Bearer write devolvem JSON do recurso atualizado" do
    client = @user.clients.create!(name: "Acme")

    post client_archival_path(client), headers: bearer(@write), as: :json

    assert_response :success
    assert client.reload.archived?
    assert response.parsed_body["archived_at"].present?

    delete client_archival_path(client), headers: bearer(@write), as: :json

    assert_response :success
    assert_not client.reload.archived?
    assert_nil response.parsed_body["archived_at"]
  end

  test "archival de recurso de outro usuário via Bearer dá 404" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.clients.create!(name: "Alheio")

    post client_archival_path(alheio), headers: bearer(@write), as: :json

    assert_response :not_found
    assert_not alheio.reload.archived?
  end

  test "archival com Bearer read é rejeitado pelo escopo de método do token" do
    client = @user.clients.create!(name: "Acme")

    post client_archival_path(client), headers: bearer(@read), as: :json

    assert_response :unauthorized
    assert_not client.reload.archived?
  end

  test "GET /reports/export.csv com Bearer read devolve o arquivo" do
    @user.time_entries.create!(
      started_at: Time.zone.parse("2026-07-10 12:00"),
      ended_at: Time.zone.parse("2026-07-10 13:00"),
      description: "Trabalho"
    )

    get export_reports_path(format: :csv), headers: bearer(@read)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "Trabalho"
  end

  test "GET /reports/export.xlsx com Bearer read devolve o arquivo" do
    @user.time_entries.create!(
      started_at: Time.zone.parse("2026-07-10 12:00"),
      ended_at: Time.zone.parse("2026-07-10 13:00")
    )

    get export_reports_path(format: :xlsx), headers: bearer(@read)

    assert_response :success
    assert_equal(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      response.media_type
    )
    assert response.body.bytesize.positive?
  end

  test "export com token inválido devolve 401" do
    get export_reports_path(format: :csv), headers: { "Authorization" => "Bearer invalido" }

    assert_response :unauthorized
  end

  private
    def bearer(token)
      { "Authorization" => "Bearer #{token.token}" }
    end
end
