require "test_helper"

class TrackerUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("tracker@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
  end

  test "home agrupa entries por dia no fuso do user e não vaza entries alheias" do
    project = @user.projects.create!(name: "Projeto local")
    older = @user.time_entries.create!(
      project: project,
      description: "Virou o dia em UTC",
      started_at: Time.utc(2026, 7, 2, 1, 30, 0),
      ended_at: Time.utc(2026, 7, 2, 2, 30, 0)
    )
    newer = @user.time_entries.create!(
      project: project,
      description: "Novo dia local",
      started_at: Time.utc(2026, 7, 2, 3, 30, 0),
      ended_at: Time.utc(2026, 7, 2, 4, 0, 0)
    )

    other = create_user(email: "other-tracker@example.com")
    other_entry = other.time_entries.create!(description: "Alheio", started_at: Time.current - 1.hour, ended_at: Time.current)

    get home_path

    assert_response :success
    assert_select "[data-day='2026-07-02']", count: 1
    assert_select "[data-day='2026-07-01']", count: 1
    assert_select "[data-entry-id='#{newer.id}']", count: 1
    assert_select "[data-entry-id='#{older.id}']", count: 1
    # Isolamento (Q23) com dentes: o `assert_select "body", text:, count: 0` casava
    # vazio (falso ok). Asserção específica no id do entry alheio + no corpo.
    assert_select "[data-entry-id='#{other_entry.id}']", count: 0
    assert_not_includes response.body, "Alheio"
  end

  test "entry RODANDO agrupa no dia do started_at, não no dia de hoje (Q6)" do
    @user.update!(time_zone: "UTC")
    running = nil
    # started em 01/07 23:00, "agora" é 02/07 01:00 (ainda rodando): tem que cair
    # no grupo de 01/07 (dia do started_at), NÃO no de 02/07 (hoje). Determinístico.
    running = @user.time_entries.create!(
      description: "Atravessou a meia-noite",
      started_at: Time.utc(2026, 7, 1, 23, 0, 0),
      ended_at: nil
    )
    travel_to Time.utc(2026, 7, 2, 1, 0, 0) do
      get home_path
    end

    assert_response :success
    assert_select "[data-day='2026-07-01'] [data-entry-id='#{running.id}']", count: 1
    assert_select "[data-day='2026-07-02'] [data-entry-id='#{running.id}']", count: 0
  end

  test "POST /timer via turbo inicia o timer e renderiza a barra no estado rodando" do
    project = @user.projects.create!(name: "Projeto turbo")

    assert_difference -> { @user.time_entries.count }, +1 do
      post timer_path,
        params: { timer: { project_id: project.id, description: "Escrevendo tracker" } },
        headers: turbo_headers("timer_bar")
    end

    entry = @user.time_entries.find_by!(ended_at: nil)
    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="timer_bar")
    assert_includes response.body, "Escrevendo tracker"
    assert_includes response.body, "Parar"
    assert_select "[data-entry-id='#{entry.id}'][data-running='true']", count: 1
  end

  test "POST /timer com timer já rodando devolve 409 e re-renderiza a barra no estado real" do
    running = @user.time_entries.create!(description: "Já rodando", started_at: Time.current - 5.minutes)

    assert_no_difference -> { @user.time_entries.count } do
      post timer_path,
        params: { timer: { description: "Segundo timer" } },
        headers: turbo_headers("timer_bar")
    end

    assert_response :conflict
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="timer_bar")
    assert_includes response.body, "Já rodando"
    assert_select "[data-entry-id='#{running.id}'][data-running='true']", count: 1
  end

  test "DELETE /timer via turbo para o timer, volta a barra ao idle e atualiza a lista da home" do
    running = @user.time_entries.create!(
      description: "Em andamento",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0)
    )

    travel_to Time.utc(2026, 7, 2, 12, 30, 0) do
      delete timer_path, headers: turbo_headers("timer_bar")
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="timer_bar")
    assert_includes response.body, %(target="tracker_entries")
    assert_includes response.body, "Iniciar"
    assert_includes response.body, "00:30:00"
    assert_equal Time.utc(2026, 7, 2, 12, 30, 0), running.reload.ended_at
  end

  test "edição inline de entry carrega e salva no mesmo turbo frame" do
    first_project = @user.projects.create!(name: "Primeiro")
    second_project = @user.projects.create!(name: "Segundo")
    entry = @user.time_entries.create!(
      project: first_project,
      description: "Antes",
      billable: true,
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )

    get edit_time_entry_path(entry), headers: turbo_frame_headers(entry)

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(entry)} form", count: 1

    patch time_entry_path(entry),
      params: {
        time_entry: {
          description: "Depois",
          project_id: second_project.id,
          started_at: "2026-07-02T09:30",
          billable: "0"
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :success
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(entry)}", count: 1
    assert_select "turbo-frame##{ActionView::RecordIdentifier.dom_id(entry)} input[name='time_entry[description]']", count: 0
    assert_select "[data-entry-id='#{entry.id}']", text: /Depois/
    assert_equal "Depois", entry.reload.description
    assert_equal second_project.id, entry.project_id
    assert_equal false, entry.billable
    assert_equal ActiveSupport::TimeZone[@user.time_zone].parse("2026-07-02T09:30").utc, entry.started_at
  end

  test "editar entry de outro user dá 404" do
    other = create_user(email: "private-entry@example.com")
    entry = other.time_entries.create!(description: "Privado", started_at: Time.current, ended_at: Time.current + 1.hour)

    get edit_time_entry_path(entry), headers: turbo_frame_headers(entry)

    assert_response :not_found
  end

  private
    def turbo_headers(frame_id)
      {
        "Turbo-Frame" => frame_id,
        "Accept" => "text/vnd.turbo-stream.html, text/html"
      }
    end

    def turbo_frame_headers(entry)
      turbo_headers(ActionView::RecordIdentifier.dom_id(entry))
    end
end
