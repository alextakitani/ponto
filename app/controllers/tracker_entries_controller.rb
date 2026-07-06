class TrackerEntriesController < ApplicationController
  include TrackerData

  def index
    authorize! TimeEntry, to: :index?

    load_tracker_day_groups
    @last_rendered_date = parse_last_rendered_date
    @continuing_day_total_seconds = tracker_day_total_seconds(@last_rendered_date)
    @continuing_day_amounts = tracker_day_total_amounts(@last_rendered_date)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to home_path(page: @tracker_pagy.page) }
    end
  end

  private
    def parse_last_rendered_date
      Date.iso8601(params[:last_date].to_s)
    rescue ArgumentError
      nil
    end
end
