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

  test "barra ociosa renderiza descrição, projeto e tags" do
    @user.tags.create!(name: "Bug")
    get timer_path, headers: turbo_headers("timer_bar")

    assert_response :success
    assert_select "form.timer-bar--idle", count: 1
    assert_select "label[for='timer_description']", text: /Descrição/
    assert_select "input[name='timer[description]']", count: 1
    assert_select "input[type='hidden'][name='timer[project_id]']", count: 1
    assert_select ".timer-project-picker", count: 1
    assert_select "input[name='timer[tag_ids][]']", minimum: 1
    assert_select "input[name='timer[new_tag_names][]']", count: 1
  end

  test "barra ociosa pré-seleciona o projeto padrão do usuário" do
    project = @user.projects.create!(name: "Padrão bar")
    @user.update!(default_project: project)

    get timer_path, headers: turbo_headers("timer_bar")

    assert_response :success
    assert_select "input[type='hidden'][name='timer[project_id]'][value='#{project.id}']", count: 1
    assert_select ".timer-project-picker__option--selected", text: "Padrão bar", count: 1
  end

  test "POST /timer via turbo inicia o timer com projeto e tags escolhidos no form" do
    project = @user.projects.create!(name: "Projeto turbo")
    bug = @user.tags.create!(name: "Bug")

    assert_difference -> { @user.time_entries.count }, +1 do
      post timer_path,
        params: { timer: { description: "Escrevendo tracker", project_id: project.id, tag_ids: [ bug.id.to_s ], new_tag_names: [ "Urgente" ] } },
        headers: turbo_headers("timer_bar")
    end

    entry = @user.time_entries.find_by!(ended_at: nil)
    assert_response :success
    assert_equal project.id, entry.project_id
    assert_equal [ "Bug", "Urgente" ], entry.tags.order(:created_at).map(&:name)
    assert_equal Mime[:turbo_stream], response.media_type
    # Regressão: o stream tem que fazer UPDATE do conteúdo do frame, não replace do
    # frame — replace trocava o frame do layout por um "nu" (sem data-turbo-permanent/
    # src/timer-bar-sync), quebrando o cronômetro-entre-telas e o sync entre abas.
    assert_match %r{turbo-stream action="update" target="timer_bar"}, response.body
    assert_includes response.body, "Escrevendo tracker"
    assert_includes response.body, "Parar"
    assert_select "[data-entry-id='#{entry.id}'][data-running='true']", count: 1
  end

  test "POST /timer via turbo sem project_id e sem projeto padrão cria entry sem projeto" do
    assert_difference -> { @user.time_entries.count }, +1 do
      post timer_path,
        params: { timer: { description: "Sem projeto padrão" } },
        headers: turbo_headers("timer_bar")
    end

    assert_response :success
    assert_nil @user.time_entries.find_by!(ended_at: nil).project_id
  end

  test "POST /timer via turbo sem project_id e padrão arquivado cria entry sem projeto" do
    project = @user.projects.create!(name: "Arquivado padrão")
    @user.update!(default_project: project)
    project.archive!

    assert_difference -> { @user.time_entries.count }, +1 do
      post timer_path,
        params: { timer: { description: "Padrão arquivado" } },
        headers: turbo_headers("timer_bar")
    end

    assert_response :success
    assert_nil @user.time_entries.find_by!(ended_at: nil).project_id
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

  # Regressão: deletar entry PARADA não pode reescrever a barra do timer — o
  # rewrite re-anima o conteúdo (barra "pula") e apaga o que estiver digitado.
  test "DELETE de entry parada via turbo não toca a barra do timer" do
    entry = @user.time_entries.create!(description: "Parada", started_at: 2.hours.ago, ended_at: 1.hour.ago)

    delete time_entry_path(entry), headers: turbo_headers("tracker_entries")

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="tracker_entries")
    assert_not_includes response.body, %(target="timer_bar")
  end

  test "DELETE da entry RODANDO via turbo volta a barra ao ocioso" do
    running = @user.time_entries.create!(description: "Rodando", started_at: 10.minutes.ago)

    delete time_entry_path(running), headers: turbo_headers("tracker_entries")

    assert_response :success
    assert_match %r{turbo-stream action="update" target="timer_bar"}, response.body
    assert_includes response.body, "Iniciar"
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
    assert_equal Mime[:turbo_stream], response.media_type
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_select "[data-entry-id='#{entry.id}']", text: /Depois/
    assert_equal "Depois", entry.reload.description
    assert_equal second_project.id, entry.project_id
    assert_equal false, entry.billable
    assert_equal ActiveSupport::TimeZone[@user.time_zone].parse("2026-07-02T09:30").utc, entry.started_at
  end

  test "edição inline com horas alteradas re-renderiza a lista do tracker" do
    entry = @user.time_entries.create!(
      description: "Horas antigas",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )

    patch time_entry_path(entry),
      params: {
        time_entry: {
          started_at: "2026-07-02T09:00",
          ended_at: "2026-07-02T11:00"
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_select "[data-entry-id='#{entry.id}'] .tracker-entry__duration", text: /02:00:00/
  end

  test "edição inline que resolve overlap remove badge dos dois entries na resposta" do
    first = @user.time_entries.create!(
      description: "Primeiro overlap",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )
    second = @user.time_entries.build(
      description: "Segundo overlap",
      started_at: Time.utc(2026, 7, 2, 12, 30, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 30, 0)
    )
    second.allow_overlap = true
    second.save!

    patch time_entry_path(second),
      params: {
        time_entry: {
          started_at: "2026-07-02T11:00",
          ended_at: "2026-07-02T12:00"
        }
      },
      headers: turbo_frame_headers(second)

    assert_response :success
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_select "[data-entry-id='#{first.id}'] .tag-badge--danger", count: 0
    assert_select "[data-entry-id='#{second.id}'] .tag-badge--danger", count: 0
  end

  test "edição inline atualiza total do dia na resposta" do
    entry = @user.time_entries.create!(
      description: "Total do dia",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )

    patch time_entry_path(entry),
      params: {
        time_entry: {
          started_at: "2026-07-02T09:00",
          ended_at: "2026-07-02T11:30"
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :success
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_select "#day-2026-07-02-totals .tracker-day__total", text: "02:30:00"
  end

  test "edição inline de entry finalizado salva início e fim editáveis" do
    entry = @user.time_entries.create!(
      description: "Antes",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )

    get edit_time_entry_path(entry), headers: turbo_frame_headers(entry)

    assert_response :success
    assert_select "input[name='time_entry[started_at]'][data-duration-fields-target='start']", count: 1
    assert_select "input[name='time_entry[ended_at]'][data-duration-fields-target='end']", count: 1
    assert_select "input[data-duration-fields-target='duration'][name]", count: 0
    assert_select ".tracker-entry__readonly", count: 0

    patch time_entry_path(entry),
      params: {
        time_entry: {
          started_at: "2026-07-02T09:30",
          ended_at: "2026-07-02T10:45"
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_equal ActiveSupport::TimeZone[@user.time_zone].parse("2026-07-02T09:30").utc, entry.reload.started_at
    assert_equal ActiveSupport::TimeZone[@user.time_zone].parse("2026-07-02T10:45").utc, entry.ended_at
  end

  test "edição inline de entry rodando ignora ended_at forjado" do
    running = @user.time_entries.create!(
      description: "Rodando",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0)
    )

    patch time_entry_path(running),
      params: {
        time_entry: {
          description: "Ainda rodando",
          ended_at: "2026-07-02T10:45"
        }
      },
      headers: turbo_frame_headers(running)

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_nil running.reload.ended_at
    assert_equal "Ainda rodando", running.description
  end

  test "edição inline rejeita fim anterior ao início" do
    entry = @user.time_entries.create!(
      description: "Antes",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )

    patch time_entry_path(entry),
      params: {
        time_entry: {
          started_at: "2026-07-02T10:00",
          ended_at: "2026-07-02T09:00"
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :unprocessable_entity
    assert_equal Time.utc(2026, 7, 2, 12, 0, 0), entry.reload.started_at
    assert_equal Time.utc(2026, 7, 2, 13, 0, 0), entry.ended_at
  end

  test "edição inline aceita tags existentes, mantém arquivada já aplicada e cria nova inline" do
    active = @user.tags.create!(name: "Bug")
    archived = @user.tags.create!(name: "Legado")
    archived.archive!
    entry = @user.time_entries.create!(
      description: "Antes",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )
    entry.tags << archived

    get edit_time_entry_path(entry), headers: turbo_frame_headers(entry)

    assert_response :success
    assert_select "input[name='time_entry[tag_ids][]'][value='#{active.id}']", count: 1
    assert_select "input[name='time_entry[tag_ids][]'][value='#{archived.id}'][checked='checked']", count: 1
    assert_select "input[name='time_entry[new_tag_names][]']", count: 1

    patch time_entry_path(entry),
      params: {
        time_entry: {
          description: "Depois",
          tag_ids: [ active.id.to_s, archived.id.to_s ],
          new_tag_names: [ "Urgente" ]
        }
      },
      headers: turbo_frame_headers(entry)

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_turbo_stream action: :replace, target: "tracker_entries"
    assert_equal [ "Bug", "Legado", "Urgente" ], entry.reload.tags.order(:created_at).map(&:name)
    assert_select "[data-entry-id='#{entry.id}']", text: /Bug/
    assert_select "[data-entry-id='#{entry.id}']", text: /Legado/
    assert_select "[data-entry-id='#{entry.id}']", text: /Urgente/
  end

  test "editar entry com tag alheia é rejeitado e não aplica nada" do
    entry = @user.time_entries.create!(
      description: "Antes",
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )
    foreign = create_user(email: "tag-alheia@example.com").tags.create!(name: "Alheia")

    patch time_entry_path(entry),
      params: { time_entry: { tag_ids: [ foreign.id.to_s ] } },
      headers: turbo_frame_headers(entry)

    assert_response :unprocessable_entity
    assert_empty entry.reload.tags
    assert_includes response.body, "não pertence a você"
  end

  test "editar entry de outro user dá 404" do
    other = create_user(email: "private-entry@example.com")
    entry = other.time_entries.create!(description: "Privado", started_at: Time.current, ended_at: Time.current + 1.hour)

    get edit_time_entry_path(entry), headers: turbo_frame_headers(entry)

    assert_response :not_found
  end

  # Regressão: o Cancelar da edição (GET do frame isolado) MANTÉM o badge de
  # sobreposição — antes o render solo vinha sem overlapping_ids e o badge sumia
  # com o conflito ainda de pé.
  test "cancelar a edição mantém o badge de sobreposição da entry" do
    first = @user.time_entries.build(description: "A", started_at: Time.utc(2026, 7, 2, 9), ended_at: Time.utc(2026, 7, 2, 10))
    first.allow_overlap = true
    first.save!
    second = @user.time_entries.build(description: "B", started_at: Time.utc(2026, 7, 2, 9, 30), ended_at: Time.utc(2026, 7, 2, 10, 30))
    second.allow_overlap = true
    second.save!

    get time_entry_path(first), headers: turbo_frame_headers(first)

    assert_response :success
    assert_select ".tag-badge--danger"
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
