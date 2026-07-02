class HomeController < ApplicationController
  layout "app"
  include TrackerData

  def show
    authorize! TimeEntry, to: :index?
    load_tracker_day_groups
  end
end
