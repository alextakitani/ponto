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

  test "load more updates the accumulated total when a day crosses the page boundary" do
    49.times do |index|
      create_entry_at("Dia novo #{index}", Time.utc(2026, 7, 3, 12, index, 0))
    end
    create_entry_at("Dia cruzado 0", Time.utc(2026, 7, 2, 12, 2, 0))
    2.times do |index|
      create_entry_at("Dia cruzado #{index + 1}", Time.utc(2026, 7, 2, 12, index, 0))
    end

    get tracker_entries_path(page: 2, last_date: "2026-07-02"), headers: turbo_stream_headers

    assert_response :success
    assert_includes response.body, %(action="replace" target="day-2026-07-02-totals")
    assert_includes response.body, "01:30:00"
  end

  test "load more ignores forged last_total when updating the continued day total" do
    49.times do |index|
      create_entry_at("Dia novo #{index}", Time.utc(2026, 7, 3, 12, index, 0))
    end
    3.times do |index|
      create_entry_at("Dia cruzado #{index}", Time.utc(2026, 7, 2, 12, index, 0))
    end

    get tracker_entries_path(page: 2, last_date: "2026-07-02", last_total: 999_999),
      headers: turbo_stream_headers

    assert_response :success
    assert_includes response.body, %(action="replace" target="day-2026-07-02-totals")
    assert_includes response.body, "01:30:00"
    assert_not_includes response.body, "277:46:39"
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

  test "command palette recent entries are scoped to the current user and ordered by most recent" do
    own_entries = 6.times.map do |index|
      entry = @user.time_entries.build(
        description: "Própria #{index}",
        started_at: Time.utc(2026, 7, 1, 8, index, 0),
        ended_at: Time.utc(2026, 7, 1, 9, index, 0)
      )
      entry.allow_overlap = true
      entry.save!
      entry
    end
    other = create_user(email: "palette-other@example.com")
    other.time_entries.create!(
      description: "Alheia muito recente",
      started_at: Time.utc(2026, 7, 3, 8, 0, 0),
      ended_at: Time.utc(2026, 7, 3, 9, 0, 0)
    )

    get home_path

    assert_response :success
    assert_select "h2", text: "Recentes"
    assert_not_includes response.body, "Alheia muito recente"

    expected = own_entries.last(5).reverse.map { |entry| "Própria #{own_entries.index(entry)}" }
    palette_labels = Nokogiri::HTML(response.body)
      .css("#command_palette [data-command-palette-label]")
      .map { |node| node["data-command-palette-label"] }

    assert palette_labels.none? { |label| label.include?("Própria 0") }

    positions = expected.map do |description|
      palette_labels.index { |label| label.include?(description) }
    end
    assert positions.all?
    assert_equal positions.sort, positions
  end

  test "tracker row shows billable amount only when the entry has billable money" do
    project = @user.projects.create!(name: "Faturável", rate_cents: 10000)
    billable = @user.time_entries.create!(
      project: project,
      description: "Com valor",
      billable: true,
      started_at: Time.utc(2026, 7, 2, 12, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 13, 0, 0)
    )
    non_billable = @user.time_entries.create!(
      project: project,
      description: "Sem valor",
      billable: false,
      started_at: Time.utc(2026, 7, 2, 10, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )
    no_rate = @user.time_entries.create!(
      description: "Sem taxa",
      started_at: Time.utc(2026, 7, 2, 8, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 9, 0, 0)
    )

    get home_path

    assert_response :success
    # O € saiu da linha (07/07): vive no title do decorrido, e SÓ quando há
    # dinheiro faturável — entry não-faturável/sem taxa não ganha tooltip.
    doc = Nokogiri::HTML(response.body)
    assert_match(/R\$\s?100,00/, doc.at_css("[data-entry-id='#{billable.id}'] .tracker-entry__duration")["title"])
    assert_nil doc.at_css("[data-entry-id='#{non_billable.id}'] .tracker-entry__duration")["title"]
    assert_nil doc.at_css("[data-entry-id='#{no_rate.id}'] .tracker-entry__duration")["title"]
  end

  private
    def create_entry_at(description, started_at)
      entry = @user.time_entries.build(
        description: description,
        started_at: started_at,
        ended_at: started_at + 30.minutes
      )
      # Dados compactos de paginação podem repetir janelas; não exercem criação manual.
      entry.allow_overlap = true
      entry.save!
      entry
    end

    def turbo_stream_headers
      { "Accept" => "text/vnd.turbo-stream.html, text/html" }
    end
end
