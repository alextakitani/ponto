require "test_helper"

# Fatia 3.3 — SPLIT (Q48): quebrar um entry finalizado em dois. Ação sem verbo padrão
# vira resource (STYLE.md): POST /time_entries/:time_entry_id/split. Testamos o fluxo
# de controle NOSSO (parse do corte, autorização/isolamento, resposta turbo), não a
# mecânica de domínio (coberta no model).
class SplitTimeEntriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("splitter@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
  end

  test "POST split quebra o entry em dois e re-renderiza a lista via turbo" do
    project = @user.projects.create!(name: "Projeto split")
    entry = @user.time_entries.create!(
      project: project,
      description: "Bloco longo",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 14, 0, 0)
    )

    assert_difference -> { @user.time_entries.count }, +1 do
      post time_entry_split_path(entry),
        params: { split: { cut: "2026-07-02T10:00" } },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="tracker_entries")

    entry.reload
    # 10:00 local (America/Sao_Paulo, UTC-3) == 13:00 UTC → corte no meio.
    assert_equal Time.utc(2026, 7, 2, 13, 0, 0), entry.ended_at
    second = @user.time_entries.where.not(id: entry.id).order(:started_at).last
    assert_equal Time.utc(2026, 7, 2, 13, 0, 0), second.started_at
    assert_equal Time.utc(2026, 7, 2, 14, 0, 0), second.ended_at
  end

  test "POST split com corte fora do intervalo devolve 422 e não cria nada" do
    project = @user.projects.create!(name: "Projeto split")
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 14, 0, 0)
    )

    assert_no_difference -> { @user.time_entries.count } do
      post time_entry_split_path(entry),
        params: { split: { cut: "2026-07-02T20:00" } },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :unprocessable_entity
    assert_equal Time.utc(2026, 7, 2, 14, 0, 0), entry.reload.ended_at
  end

  test "POST split de entry já sobreposto funciona sem erro" do
    project = @user.projects.create!(name: "Projeto split")
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 14, 0, 0)
    )
    overlapping = @user.time_entries.build(
      project: project,
      started_at: Time.utc(2026, 7, 2, 12, 30, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 30, 0)
    )
    overlapping.allow_overlap = true
    overlapping.save!

    assert_difference -> { @user.time_entries.count }, +1 do
      post time_entry_split_path(entry),
        params: { split: { cut: "2026-07-02T10:00" } },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :success
    assert_equal Time.utc(2026, 7, 2, 13, 0, 0), entry.reload.ended_at
  end

  test "split de entry de outro user dá 404 (isolamento Q23)" do
    other = create_user(email: "outro-split@example.com")
    alheio = other.time_entries.create!(
      description: "Privado",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 14, 0, 0)
    )

    assert_no_difference -> { TimeEntry.count } do
      post time_entry_split_path(alheio),
        params: { split: { cut: "2026-07-02T13:00" } },
        headers: turbo_headers("tracker_entries")
    end

    assert_response :not_found
  end

  private
    def turbo_headers(frame_id)
      {
        "Turbo-Frame" => frame_id,
        "Accept" => "text/vnd.turbo-stream.html, text/html"
      }
    end
end
