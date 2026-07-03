require "test_helper"

# Fatia 3.3 — ENTRY MANUAL (Q46/Q5). Cria um entry JÁ FINALIZADO com início+fim reais
# (o Stimulus dos campos ligados converte duração→fim ANTES do submit; o servidor só
# recebe dois timestamps). Testamos o fluxo NOSSO: parse do fuso do user, snapshot
# congelado, validação ended>started e a resposta turbo que re-renderiza a lista.
class ManualTimeEntriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("manual@example.com")
    @user.update!(time_zone: "America/Sao_Paulo") # UTC-3
  end

  test "cria entry manual finalizado interpretando início/fim no fuso do user e re-renderiza a lista" do
    project = @user.projects.create!(name: "Projeto manual", rate_cents: 12000)
    existing = @user.tags.create!(name: "Reunião")

    assert_difference -> { @user.time_entries.count }, +1 do
      post time_entries_path,
        params: {
          time_entry: {
            project_id: project.id,
            description: "Reunião de ontem",
            started_at: "2026-07-01T09:00",
            ended_at: "2026-07-01T10:30",
            tag_ids: [ existing.id.to_s ],
            new_tag_names: [ "Cliente" ]
          }
        },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="tracker_entries")

    entry = @user.time_entries.order(:created_at).last
    # 09:00 local (UTC-3) == 12:00 UTC.
    assert_equal Time.utc(2026, 7, 1, 12, 0, 0), entry.started_at
    assert_equal Time.utc(2026, 7, 1, 13, 30, 0), entry.ended_at
    assert_equal 5400, entry.duration_seconds
    # Snapshot congela a rate efetiva do projeto no create.
    assert_equal 12000, entry.rate_cents
    assert_equal [ "Cliente", "Reunião" ], entry.tags.map(&:name).sort
  end

  test "entry manual com fim <= início não cria nada e devolve 422" do
    project = @user.projects.create!(name: "Projeto manual")

    assert_no_difference -> { @user.time_entries.count } do
      post time_entries_path,
        params: {
          time_entry: {
            project_id: project.id,
            started_at: "2026-07-01T10:00",
            ended_at: "2026-07-01T09:00"
          }
        },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :unprocessable_entity
  end

  private
    def turbo_headers(frame_id)
      {
        "Turbo-Frame" => frame_id,
        "Accept" => "text/vnd.turbo-stream.html, text/html"
      }
    end
end
