require "csv"

class Clockify::Import
  Source = Data.define(:name, :content) do
    # O conteúdo pode chegar ASCII-8BIT (bytes crus) — o Active Storage#download
    # entrega assim. O CSV do Clockify é UTF-8; re-etiqueta e limpa bytes inválidos
    # AQUI, na entrada única, pra toda string derivada (description, nomes, tags) já
    # nascer UTF-8. Sem isso, o insert no SQLite estoura em acento
    # (Encoding::UndefinedConversionError ASCII-8BIT→UTF-8). File.read (console) já
    # vinha UTF-8 e mascarava o bug — só a UI via Active Storage disparava.
    def read
      content.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    end
  end

  Result = Data.define(
    :clients_created,
    :projects_created,
    :tasks_created,
    :tags_created,
    :time_entries_created
  )

  Error = Class.new(StandardError)

  HEADER_COLUMNS = [
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
    "Billable Rate",
    "Billable Amount",
    "Date of creation"
  ].freeze

  HEADER_PATTERN = [
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
    /\ABillable Rate \(([A-Z]{3})\)\z/,
    /\ABillable Amount \(([A-Z]{3})\)\z/,
    "Date of creation"
  ].freeze

  def initialize(user:, sources:)
    @user = user
    @sources = sources
  end

  def run!
    ActiveRecord::Base.transaction do
      ensure_empty_bubble!
      rows_by_file = parse_sources
      rows = rows_by_file.flat_map(&:rows)

      raise_error(:all_files_empty) if rows.empty?

      currency = validate_cross_file_currency!(rows_by_file)
      create_records(rows, currency)
    end
  end

  private
    ParsedFile = Data.define(:name, :currency, :rows)

    attr_reader :user, :sources

    def ensure_empty_bubble!
      return unless user.clients.exists? ||
        user.projects.exists? ||
        user.tasks.exists? ||
        user.tags.exists? ||
        user.time_entries.exists?

      raise_error(:non_empty_bubble)
    end

    def parse_sources
      sources.map { |source| parse_source(source) }
    end

    def parse_source(source)
      csv = CSV.parse(source.read, headers: true)
      currency = validate_header!(source.name, csv.headers)
      rows = csv.each.with_index(2).map do |csv_row, row_number|
        Clockify::Import::Row.new(
          attributes: row_attributes(csv_row),
          file: source.name,
          row_number:,
          time_zone:
        )
      end

      ParsedFile.new(source.name, currency, rows)
    rescue CSV::MalformedCSVError
      raise_error(:header_mismatch, file: source.name)
    end

    def validate_header!(file, header)
      match = header.present? &&
        header.size == HEADER_PATTERN.size &&
        header.zip(HEADER_PATTERN).all? do |actual, expected|
          expected.is_a?(Regexp) ? actual.match?(expected) : actual == expected
        end

      raise_error(:header_mismatch, file:) unless match

      rate_currency = header[15].match(HEADER_PATTERN[15])[1]
      amount_currency = header[16].match(HEADER_PATTERN[16])[1]
      raise_error(:divergent_currency, file:) if amount_currency != rate_currency

      rate_currency
    end

    def row_attributes(csv_row)
      attributes = HEADER_COLUMNS.index_with { |column| csv_row[column] }
      attributes["Billable Rate"] = csv_row[15]
      attributes["Billable Amount"] = csv_row[16]
      attributes
    end

    def validate_cross_file_currency!(parsed_files)
      non_empty_files = parsed_files.reject { |parsed_file| parsed_file.rows.empty? }
      currency = non_empty_files.first.currency
      divergent = non_empty_files.find { |parsed_file| parsed_file.currency != currency }

      if divergent
        raise_error(:cross_file_currency, file1: non_empty_files.first.name, file2: divergent.name)
      end

      currency
    end

    def create_records(rows, currency)
      clients = create_clients(rows, currency)
      projects = create_projects(rows, clients)
      tasks = create_tasks(rows, projects)
      tags = create_tags(rows)

      rows.each do |row|
        entry = user.time_entries.create!(
          project: projects[project_key(row.project_name)],
          task: tasks[[ project_key(row.project_name), Task.normalize_name(row.task_name) ]],
          description: row.description,
          billable: row.billable,
          started_at: row.started_at,
          ended_at: row.ended_at
        )

        row.tag_names.each do |tag_name|
          Tagging.create!(time_entry: entry, tag: tags.fetch(Tag.normalize_name(tag_name)))
        end
      end

      Result.new(
        clients.size,
        projects.size,
        tasks.size,
        tags.size,
        rows.size
      )
    end

    def create_clients(rows, currency)
      rows.filter_map(&:client_name).uniq { |name| Client.normalize_name(name) }.to_h do |name|
        [ client_key(name), user.clients.create!(name:, currency:) ]
      end
    end

    def create_projects(rows, clients)
      rows_with_project = rows.select { |row| row.project_name.present? }
      ensure_project_rates_are_stable!(rows_with_project)

      rows_with_project.group_by { |row| Project.normalize_name(row.project_name) }.transform_values do |project_rows|
        first_row = project_rows.first
        user.projects.create!(
          name: first_row.project_name,
          client: clients[client_key(first_row.client_name)],
          rate_cents: first_row.rate_cents
        )
      end
    end

    def ensure_project_rates_are_stable!(rows)
      rows.group_by { |row| Project.normalize_name(row.project_name) }.each do |_project_key, project_rows|
        next if project_rows.map(&:rate_cents).uniq.one?

        raise_error(:divergent_project_rate, project: project_rows.first.project_name)
      end
    end

    def create_tasks(rows, projects)
      rows.select { |row| row.project_name.present? && row.task_name.present? }
        .uniq { |row| [ Project.normalize_name(row.project_name), Task.normalize_name(row.task_name) ] }
        .to_h do |row|
          key = [ Project.normalize_name(row.project_name), Task.normalize_name(row.task_name) ]
          task = user.tasks.create!(
            name: row.task_name,
            project: projects.fetch(project_key(row.project_name))
          )

          [ key, task ]
        end
    end

    def create_tags(rows)
      rows.flat_map(&:tag_names).uniq { |name| Tag.normalize_name(name) }.to_h do |name|
        [ Tag.normalize_name(name), user.tags.create!(name:) ]
      end
    end

    def project_key(name)
      Project.normalize_name(name)
    end

    def client_key(name)
      name.present? ? Client.normalize_name(name) : nil
    end

    def time_zone
      ActiveSupport::TimeZone[user.time_zone]
    end

    def raise_error(key, **options)
      raise Error, I18n.t!("clockify_import.errors.#{key}", **options)
    end
end
