require "test_helper"

class TrackerPowerUserPathsTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("power@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
  end

  test "tracker paginates by fifty entries and load more appends the next page" do
    recent_entries = 50.times.map do |index|
      create_entry_at("Recente #{index}", Time.utc(2026, 7, 3, 12, index, 0))
    end
    older = create_entry_at("Mais antiga", Time.utc(2026, 7, 2, 12, 0, 0))

    get home_path

    assert_response :success
    assert_select "[data-entry-id='#{recent_entries.last.id}']", count: 1
    assert_select "[data-entry-id='#{recent_entries.first.id}']", count: 1
    assert_select "[data-entry-id='#{older.id}']", count: 0
    assert_select "a", text: "Carregar mais" do |links|
      assert links.any? { |link| link["href"].include?("page=2") }
    end

    get tracker_entries_path(page: 2, last_date: "2026-07-03"), headers: turbo_stream_headers

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(action="append" target="tracker_entries")
    assert_includes response.body, %(data-entry-id="#{older.id}")
  end

  test "load more merges entries when a day crosses the page boundary" do
    49.times do |index|
      create_entry_at("Dia novo #{index}", Time.utc(2026, 7, 3, 12, index, 0))
    end
    first_page_same_day = create_entry_at("Dia cruzado 0", Time.utc(2026, 7, 2, 12, 2, 0))
    second_page_same_day = [
      create_entry_at("Dia cruzado 1", Time.utc(2026, 7, 2, 12, 1, 0)),
      create_entry_at("Dia cruzado 2", Time.utc(2026, 7, 2, 12, 0, 0))
    ]

    get home_path

    assert_response :success
    assert_select "section#day-2026-07-02", count: 1
    assert_select "section#day-2026-07-02 [data-entry-id='#{first_page_same_day.id}']", count: 1

    get tracker_entries_path(page: 2, last_date: "2026-07-02"), headers: turbo_stream_headers

    assert_response :success
    assert_includes response.body, %(action="append" target="day-2026-07-02-entries")
    assert_not_includes response.body, %(id="day-2026-07-02")
    second_page_same_day.each do |entry|
      assert_includes response.body, %(data-entry-id="#{entry.id}")
    end
  end

  test "running timer is included on the first tracker page" do
    60.times do |index|
      create_entry_at("Finalizada #{index}", Time.utc(2026, 7, 1, 8, index % 60, 0))
    end
    running = @user.time_entries.create!(
      description: "Rodando agora",
      started_at: Time.utc(2026, 7, 3, 12, 0, 0)
    )

    get home_path

    assert_response :success
    assert_select "[data-entry-id='#{running.id}'][data-running='true']", count: 1
  end

  test "retomar ultima copies the latest finished description and project into a new running timer" do
    project = @user.projects.create!(name: "Projeto retomado")
    old_project = @user.projects.create!(name: "Projeto antigo")
    @user.time_entries.create!(
      project: old_project,
      description: "Entrada antiga",
      started_at: Time.utc(2026, 7, 1, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 10, 0, 0)
    )
    latest = @user.time_entries.create!(
      project: project,
      description: "Entrada recente",
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 0, 0)
    )

    assert_difference -> { @user.time_entries.count }, +1 do
      post latest_time_entry_restart_path, headers: turbo_headers("timer_bar")
    end

    assert_response :success
    running = @user.time_entries.find_by!(ended_at: nil)
    assert_not_equal latest.id, running.id
    assert_equal "Entrada recente", running.description
    assert_equal project.id, running.project_id
  end

  test "retomar ultima with a running timer returns 409 and does not create another entry" do
    @user.time_entries.create!(
      description: "Finalizada",
      started_at: Time.utc(2026, 7, 1, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 10, 0, 0)
    )
    running = @user.time_entries.create!(description: "Já está rodando", started_at: Time.current - 5.minutes)

    assert_no_difference -> { @user.time_entries.count } do
      post latest_time_entry_restart_path, headers: turbo_headers("timer_bar")
    end

    assert_response :conflict
    assert_equal running.id, @user.time_entries.find_by!(ended_at: nil).id
    assert_includes response.body, "Timer já está rodando."
    assert_includes response.body, "Já está rodando"
  end

  test "command palette recent entries are scoped to the current user and ordered by most recent" do
    own_entries = 6.times.map do |index|
      @user.time_entries.create!(
        description: "Própria #{index}",
        started_at: Time.utc(2026, 7, 1, 8, index, 0),
        ended_at: Time.utc(2026, 7, 1, 9, index, 0)
      )
    end
    other = create_user(email: "palette-other@example.com")
    other.time_entries.create!(
      description: "Alheia muito recente",
      started_at: Time.utc(2026, 7, 3, 8, 0, 0),
      ended_at: Time.utc(2026, 7, 3, 9, 0, 0)
    )

    get command_palette_path

    assert_response :success
    assert_select "h2", text: "Recentes"
    assert_not_includes response.body, "Alheia muito recente"
    assert_not_includes response.body, "Própria 0"

    expected = own_entries.last(5).reverse.map { |entry| "Própria #{own_entries.index(entry)}" }
    positions = expected.map { |description| response.body.index(description) }
    assert positions.all?
    assert_equal positions.sort, positions
  end

  private
    def create_entry_on_local_date(description, date)
      zone = ActiveSupport::TimeZone[@user.time_zone]
      started_at = zone.local(date.year, date.month, date.day, 9, 0, 0)

      @user.time_entries.create!(
        description: description,
        started_at: started_at,
        ended_at: started_at + 1.hour
      )
    end

    def create_entry_at(description, started_at)
      @user.time_entries.create!(
        description: description,
        started_at: started_at,
        ended_at: started_at + 30.minutes
      )
    end

    def turbo_headers(frame_id)
      turbo_stream_headers.merge("Turbo-Frame" => frame_id)
    end

    def turbo_stream_headers
      { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end
end
