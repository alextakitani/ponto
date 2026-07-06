require "test_helper"
require "turbo/broadcastable/test_helper"

class ClockifyImportJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "success path completes the import and purges files" do
    import = create_import_with_file(csv(row))

    ClockifyImportJob.new.perform(import)

    import.reload
    assert_equal "completed", import.status
    assert_operator import.clients_created, :>, 0
    assert_operator import.projects_created, :>, 0
    assert_operator import.tasks_created, :>, 0
    assert_operator import.tags_created, :>, 0
    assert_operator import.time_entries_created, :>, 0
    assert import.files_purged?
    assert_not import.files.attached?
  end

  # Regressão (06/07): import completava mas onboarded_at ficava nil porque só o
  # botão "Ir pro tracker" gravava — quem saía do resumo sem clicar ficava preso
  # no /welcome com bolha cheia. Q4: onboarded grava NO SUCESSO do import.
  test "success path marks the user as onboarded" do
    import = create_import_with_file(csv(row), user: create_user(onboarded_at: nil))
    assert_nil import.user.onboarded_at

    ClockifyImportJob.new.perform(import)

    assert_not_nil import.user.reload.onboarded_at
  end

  test "failure path does not onboard the user" do
    import = create_import_with_file("Nome,Valor\nx,1\n", user: create_user(onboarded_at: nil))

    ClockifyImportJob.new.perform(import)

    assert_nil import.user.reload.onboarded_at
  end

  test "import errors fail and keep attached files" do
    import = create_import_with_file("Nome,Valor\nx,1\n")

    ClockifyImportJob.new.perform(import)

    import.reload
    assert_equal "failed", import.status
    assert_predicate import.error_message, :present?
    assert import.files.attached?
  end

  test "unexpected errors fail deterministically and keep attached files" do
    import = create_import_with_file(csv(row))
    original_new = Clockify::Import.method(:new)
    Clockify::Import.define_singleton_method(:new) { |*| raise StandardError, "boom" }

    ClockifyImportJob.new.perform(import)

    import.reload
    assert_equal "failed", import.status
    assert_equal I18n.t("clockify_import.errors.unexpected"), import.error_message
    assert import.files.attached?
  ensure
    Clockify::Import.define_singleton_method(:new, original_new)
  end

  test "uses the import user and leaves other users untouched" do
    user = create_user
    other_user = create_user(email: "other@example.com")
    other_client = other_user.clients.create!(name: "Existing", currency: "EUR")
    import = create_import_with_file(csv(row), user:)

    ClockifyImportJob.new.perform(import)

    assert_equal "completed", import.reload.status
    assert_equal [ other_client ], other_user.clients.reload.to_a
    assert_equal 0, other_user.projects.count
    assert_equal 0, other_user.tasks.count
    assert_equal 0, other_user.tags.count
    assert_equal 0, other_user.time_entries.count
  end

  test "success broadcasts on the import stream" do
    import = create_import_with_file(csv(row))

    assert_turbo_stream_broadcasts(import) do
      perform_enqueued_jobs do
        ClockifyImportJob.new.perform(import)
      end
    end
  end

  test "failure broadcasts on the import stream" do
    import = create_import_with_file("Nome,Valor\nx,1\n")

    assert_turbo_stream_broadcasts(import) do
      perform_enqueued_jobs do
        ClockifyImportJob.new.perform(import)
      end
    end
  end

  private
    def create_import_with_file(content, user: create_user)
      ClockifyImport.create!(user:).tap do |import|
        import.files.attach(
          io: StringIO.new(content),
          filename: "clockify.csv",
          content_type: "text/csv"
        )
      end
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
end
