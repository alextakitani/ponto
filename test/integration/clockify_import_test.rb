require "test_helper"

class ClockifyImportTest < ActionDispatch::IntegrationTest
  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  test "multi-file upload creates import and redirects to show" do
    user = create_user(email: "upload@example.com", onboarded_at: nil)
    sign_in_as("upload@example.com", user:)

    assert_difference -> { ClockifyImport.where(user:).count }, 1 do
      post clockify_imports_path, params: {
        clockify_import: {
          files: [
            upload(csv(row(project: "LaKube")), "clockify-2024.csv"),
            upload(csv(row(project: "Kube", start_date: "07/04/2025", end_date: "07/04/2025")), "clockify-2025.csv")
          ]
        }
      }
    end

    import = user.clockify_imports.last
    assert_redirected_to clockify_import_path(import)
    assert_equal "pending", import.status
    assert_equal 2, import.files.count
    assert_enqueued_with job: ClockifyImportJob, args: [ import ]
  end

  test "show renders processing before job runs" do
    user = create_user(email: "processing@example.com", onboarded_at: nil)
    sign_in_as("processing@example.com", user:)
    import = create_import(user:, content: csv(row))

    get clockify_import_path(import)

    assert_response :success
    assert_select "h2", I18n.t("clockify_imports.show.processing.title")
  end

  test "show renders summary after job completes" do
    user = create_user(email: "summary@example.com", onboarded_at: nil, time_zone: "America/Sao_Paulo")
    sign_in_as("summary@example.com", user:)

    perform_enqueued_jobs do
      post clockify_imports_path, params: {
        clockify_import: {
          files: [
            upload(csv(row(start_date: "01/10/2024", end_date: "01/10/2024")), "clockify-2024.csv"),
            upload(csv(row(project: "Kube", start_date: "02/10/2025", end_date: "02/10/2025")), "clockify-2025.csv")
          ]
        }
      }
    end

    import = user.clockify_imports.last
    get clockify_import_path(import)

    assert_response :success
    assert_select "h2", I18n.t("clockify_imports.show.completed.title")
    assert_select ".clockify-import-summary dd", text: "1"
    assert_select ".clockify-import-summary dd", text: "2"
    assert_select ".clockify-import-summary dd", text: "2024–2025"
    assert_includes response.body, I18n.t("clockify_imports.show.completed.files_purged")
  end

  test "error path shows failure state" do
    user = create_user(email: "failed@example.com", onboarded_at: nil)
    sign_in_as("failed@example.com", user:)
    import = create_import(user:, content: "Nome,Valor\nx,1\n")

    ClockifyImportJob.new.perform(import)
    get clockify_import_path(import)

    assert_response :success
    assert_select "h2", I18n.t("clockify_imports.show.failed.title")
    assert_includes response.body, import.reload.error_message
  end

  test "non-empty bubble hides form on new" do
    user = create_user(email: "non-empty@example.com", onboarded_at: nil)
    user.clients.create!(name: "Existing", currency: "BRL")
    sign_in_as("non-empty@example.com", user:)

    get new_clockify_import_path

    assert_response :success
    assert_select "input[type=file]", count: 0
    assert_select "h2", I18n.t("clockify_imports.new.blocked.title")
  end

  test "non-empty bubble refuses create and redirects back" do
    user = create_user(email: "non-empty-create@example.com", onboarded_at: nil)
    user.clients.create!(name: "Existing", currency: "BRL")
    sign_in_as("non-empty-create@example.com", user:)

    assert_no_difference -> { ClockifyImport.where(user:).count } do
      post clockify_imports_path, params: {
        clockify_import: { files: [ upload(csv(row), "clockify.csv") ] }
      }, headers: { "HTTP_REFERER" => new_clockify_import_url }
    end

    assert_redirected_to new_clockify_import_path
    assert_equal I18n.t("clockify_imports.create.non_empty_bubble"), flash[:alert]
  end

  test "zero files rerenders new" do
    user = create_user(email: "zero-files@example.com", onboarded_at: nil)
    sign_in_as("zero-files@example.com", user:)

    assert_no_difference -> { ClockifyImport.where(user:).count } do
      post clockify_imports_path, params: { clockify_import: { files: [] } }
    end

    assert_response :unprocessable_entity
    assert_select ".form-errors", I18n.t("clockify_imports.new.form.files_blank")
  end

  test "other users get 404 for import show" do
    owner = create_user(email: "owner@example.com", onboarded_at: nil)
    other = create_user(email: "other-import@example.com", onboarded_at: nil)
    import = create_import(user: owner, content: csv(row))
    sign_in_as("other-import@example.com", user: other)

    get clockify_import_path(import)

    assert_response :not_found
  end

  test "non-onboarded user reaches new create and show" do
    user = create_user(email: "new-user@example.com", onboarded_at: nil)
    sign_in_as("new-user@example.com", user:)

    get new_clockify_import_path
    assert_response :success

    post clockify_imports_path, params: {
      clockify_import: { files: [ upload(csv(row), "clockify.csv") ] }
    }
    import = user.clockify_imports.last

    assert_redirected_to clockify_import_path(import)
    get clockify_import_path(import)
    assert_response :success
  end

  private
    def create_import(user:, content:)
      ClockifyImport.create!(user:).tap do |import|
        import.files.attach(
          io: StringIO.new(content),
          filename: "clockify.csv",
          content_type: "text/csv"
        )
      end
    end

    def upload(content, filename = "clockify.csv")
      tempfile = Tempfile.new([ File.basename(filename, ".csv"), ".csv" ])
      tempfile.binmode
      tempfile.write(content)
      tempfile.rewind
      Rack::Test::UploadedFile.new(tempfile.path, "text/csv", original_filename: filename)
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
      start_date: "07/04/2024",
      start_time: "09:00:00 AM",
      end_date: "07/04/2024",
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
        "07/04/2024"
      ]
    end
end
