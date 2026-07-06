class Clockify::Import::Row
  ATTRIBUTES = [
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

  attr_reader :project_name, :client_name, :description, :task_name, :tag_names,
    :billable, :started_at, :ended_at, :rate_cents

  def initialize(attributes:, file:, row_number:, time_zone:)
    @attributes = attributes
    @file = file
    @row_number = row_number
    @time_zone = time_zone

    normalize!
  end

  private
    attr_reader :attributes, :file, :row_number, :time_zone

    def normalize!
      @project_name = stripped("Project")
      @client_name = stripped("Client")
      @description = stripped("Description").to_s
      @task_name = stripped("Task")
      @tag_names = stripped("Tags").to_s.split(",").map(&:strip).reject(&:blank?)
      @billable = parse_billable
      @started_at = parse_timestamp!("Start Date", "Start Time")
      @ended_at = parse_ended_at!
      @rate_cents = parse_rate_cents

      validate_time_order!
    end

    def stripped(key)
      attributes.fetch(key).to_s.strip.presence
    end

    def parse_billable
      stripped("Billable") == "Yes"
    end

    def parse_ended_at!
      if stripped("End Date").blank? || stripped("End Time").blank?
        raise_error(:timer_running, file:, row: row_number)
      end

      parse_timestamp!("End Date", "End Time")
    end

    def parse_timestamp!(date_field, time_field)
      date = stripped(date_field)
      time = stripped(time_field)
      value = [ date, time ].compact.join(" ")

      raise_unparseable!(date_field, value) if date.blank? || time.blank?

      time_zone.strptime(value, "%m/%d/%Y %I:%M:%S %p").utc
    rescue ArgumentError
      raise_unparseable!(date_field, value)
    end

    def raise_unparseable!(field, value)
      raise_error(:unparseable_date, file:, row: row_number, field:, value:)
    end

    def parse_rate_cents
      (BigDecimal(stripped("Billable Rate").to_s) * 100).round.to_i
    rescue ArgumentError
      raise_error(:unparseable_date, file:, row: row_number, field: "Billable Rate", value: stripped("Billable Rate"))
    end

    def validate_time_order!
      return if ended_at > started_at

      raise_error(:ended_before_started, file:, row: row_number)
    end

    def raise_error(key, **options)
      raise Clockify::Import::Error, I18n.t!("clockify_import.errors.#{key}", **options)
    end
end
