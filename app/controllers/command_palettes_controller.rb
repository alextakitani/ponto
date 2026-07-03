class CommandPalettesController < ApplicationController
  def show
    authorize! TimeEntry, to: :index?

    @current_timer = authorized_scope(TimeEntry.all).find_by(ended_at: nil)
    @recent_time_entries = authorized_scope(TimeEntry.all)
      .where.not(ended_at: nil)
      .includes(:project)
      .order(ended_at: :desc, id: :desc)
      .limit(5)

    render layout: false
  end
end
