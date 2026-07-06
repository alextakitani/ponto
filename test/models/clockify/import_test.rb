require "test_helper"

class Clockify::ImportTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  test "happy path creates the expected entities" do
    user = create_user

    result = import(user, csv(row(tags: "maintenance, development"))).run!

    assert_equal 1, result.clients_created
    assert_equal 1, result.projects_created
    assert_equal 1, result.tasks_created
    assert_equal 2, result.tags_created
    assert_equal 1, result.time_entries_created
    assert_equal 1, user.clients.count
    assert_equal 1, user.projects.count
    assert_equal 1, user.tasks.count
    assert_equal 2, user.tags.count
    assert_equal 1, user.time_entries.count
    assert_equal 2, Tagging.joins(:time_entry).where(time_entries: { user_id: user.id }).count
  end

  test "snapshots rate and currency from the imported project" do
    user = create_user

    import(user, csv(row(rate: "38.40"), currency: "EUR")).run!

    entry = user.time_entries.sole
    assert_equal 3840, entry.rate_cents
    assert_equal "EUR", entry.currency
  end

  test "parses local dates into UTC" do
    user = create_user(time_zone: "America/Sao_Paulo")

    import(user, csv(row(start_date: "07/04/2025", start_time: "09:00:00 AM"))).run!

    assert_equal "2025-07-04T12:00:00Z", user.time_entries.sole.started_at.utc.iso8601
  end

  test "splits tags and ignores an empty tag column" do
    user = create_user
    content = csv(
      row(project: "LaKube", tags: "maintenance, development"),
      row(project: "Kube", client: "Samuel", task: "Ops", tags: "", rate: "10.00")
    )

    import(user, content).run!

    assert_equal 2, user.tags.count
    assert_equal 2, user.time_entries.first.taggings.count
    assert_equal 0, user.time_entries.order(:id).last.taggings.count
  end

  test "importing overlapping entries still creates all records" do
    user = create_user
    content = csv(
      row(start_time: "09:00:00 AM", end_time: "10:00:00 AM"),
      row(start_time: "09:30:00 AM", end_time: "10:30:00 AM")
    )

    result = import(user, content).run!

    assert_equal 2, result.time_entries_created
    assert_equal 2, user.time_entries.count
  end

  test "billable follows the CSV column" do
    user = create_user

    import(user, csv(row(billable: "No", rate: "38.40"))).run!

    entry = user.time_entries.sole
    assert_not entry.billable?
    assert_equal 3840, entry.rate_cents
  end

  test "non empty bubble raises an import error" do
    user = create_user
    user.clients.create!(name: "Existing", currency: "EUR")

    assert_raises(Clockify::Import::Error) do
      import(user, csv(row)).run!
    end
  end

  test "mixed currency within a file raises an import error" do
    user = create_user
    content = csv(row, currency: "EUR", amount_currency: "USD")

    assert_raises(Clockify::Import::Error) do
      import(user, content).run!
    end
  end

  test "row without end date or time raises and rolls back" do
    user = create_user
    content = csv(row(end_date: "", end_time: ""))

    error = assert_raises(Clockify::Import::Error) do
      import(user, content).run!
    end

    assert_includes error.message, "clockify.csv"
    assert_includes error.message, "2"
    assert_empty_bubble(user)
  end

  test "unparseable date raises an error naming file and row" do
    user = create_user

    error = assert_raises(Clockify::Import::Error) do
      import(user, csv(row(start_date: "not-a-date"))).run!
    end

    assert_includes error.message, "clockify.csv"
    assert_includes error.message, "2"
  end

  test "divergent project rate across rows raises an import error" do
    user = create_user
    content = csv(
      row(project: "LaKube", rate: "38.40"),
      row(project: "LaKube", rate: "42.00", start_time: "10:00:00 AM", end_time: "11:00:00 AM")
    )

    assert_raises(Clockify::Import::Error) do
      import(user, content).run!
    end
  end

  test "multi file repeated entities are created once" do
    user = create_user
    first = source("2024.csv", csv(row(tags: "maintenance")))
    second = source(
      "2025.csv",
      csv(row(tags: "maintenance", start_time: "10:00:00 AM", end_time: "11:00:00 AM"))
    )

    Clockify::Import.new(user:, sources: [ first, second ]).run!

    assert_equal 1, user.clients.count
    assert_equal 1, user.projects.count
    assert_equal 1, user.tasks.count
    assert_equal 1, user.tags.count
    assert_equal 2, user.time_entries.count
  end

  test "zero rate without client snapshots zero BRL" do
    user = create_user

    import(user, csv(row(client: "", rate: "0.00"), currency: "EUR")).run!

    entry = user.time_entries.sole
    assert_equal 0, entry.rate_cents
    assert_equal "BRL", entry.currency
  end

  test "header only files are ignored unless all files are header only" do
    user = create_user
    empty = source("empty.csv", csv)
    data = source("data.csv", csv(row))

    Clockify::Import.new(user:, sources: [ empty, data ]).run!

    assert_equal 1, user.time_entries.count

    empty_user = create_user(email: "empty@example.com")
    assert_raises(Clockify::Import::Error) do
      Clockify::Import.new(user: empty_user, sources: [ empty ]).run!
    end
  end

  test "divergent currency across files raises and names both files" do
    user = create_user
    eur = source("2024.csv", csv(row, currency: "EUR"))
    usd = source("2025.csv", csv(row(rate: "10.00"), currency: "USD"))

    error = assert_raises(Clockify::Import::Error) do
      Clockify::Import.new(user:, sources: [ eur, usd ]).run!
    end

    assert_includes error.message, "2024.csv"
    assert_includes error.message, "2025.csv"
    assert_empty_bubble(user)
  end

  test "entry ending before starting raises and rolls back" do
    user = create_user
    content = csv(row(start_time: "10:00:00 AM", end_time: "09:00:00 AM"))

    error = assert_raises(Clockify::Import::Error) do
      import(user, content).run!
    end

    assert_includes error.message, "clockify.csv"
    assert_includes error.message, "2"
    assert_empty_bubble(user)
  end

  test "file with a non clockify header raises naming the file" do
    user = create_user
    foreign = "Nome,Valor\nx,1\n"

    error = assert_raises(Clockify::Import::Error) do
      import(user, foreign, name: "planilha.csv").run!
    end

    assert_includes error.message, "planilha.csv"
    assert_empty_bubble(user)
  end

  # Regressão (06/07): o Active Storage#download entrega o CSV como ASCII-8BIT; com
  # acento na descrição, o insert estourava Encoding::UndefinedConversionError ao
  # gravar em claro (a cripto antiga mascarava). Source#read re-etiqueta pra UTF-8.
  test "importa conteúdo ASCII-8BIT com acento (caminho do Active Storage)" do
    user = create_user
    content = csv(row(description: "migração do ingress", project: "Ácaro"))
    ascii_8bit = content.dup.force_encoding(Encoding::ASCII_8BIT)

    import(user, ascii_8bit).run!

    assert_equal "migração do ingress", user.time_entries.sole.description
    assert_equal "Ácaro", user.projects.sole.name
  end

  private
    def import(user, content, name: "clockify.csv")
      Clockify::Import.new(user:, sources: [ source(name, content) ])
    end

    def source(name, content)
      Clockify::Import::Source.new(name:, content:)
    end

    def csv(*rows, currency: "EUR", amount_currency: currency)
      header = [
        "Project",
        "Client",
        "Description",
        "Task",
        "User",
        "Group",
        "Email",
        "Tags",
        "Billable",
        "Start Date",
        "Start Time",
        "End Date",
        "End Time",
        "Duration (h)",
        "Duration (decimal)",
        "Billable Rate (#{currency})",
        "Billable Amount (#{amount_currency})",
        "Date of creation"
      ]

      CSV.generate do |generated|
        generated << header
        rows.each { |values| generated << values }
      end
    end

    def row(
      project: "LaKube",
      client: "Samuel",
      description: "build import",
      task: "Development",
      tags: "maintenance",
      billable: "Yes",
      start_date: "07/04/2025",
      start_time: "09:00:00 AM",
      end_date: "07/04/2025",
      end_time: "10:00:00 AM",
      rate: "38.40"
    )
      [
        project,
        client,
        description,
        task,
        "Alex",
        "",
        "alex@example.com",
        tags,
        billable,
        start_date,
        start_time,
        end_date,
        end_time,
        "01:00:00",
        "1.00",
        rate,
        rate,
        "07/04/2025"
      ]
    end

    def assert_empty_bubble(user)
      assert_equal 0, user.clients.count
      assert_equal 0, user.projects.count
      assert_equal 0, user.tasks.count
      assert_equal 0, user.tags.count
      assert_equal 0, user.time_entries.count
    end
end
