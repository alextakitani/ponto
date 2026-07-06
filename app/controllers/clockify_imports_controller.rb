class ClockifyImportsController < ApplicationController
  layout "app"

  def new
    authorize! ClockifyImport, to: :new?
    @empty_bubble = Current.user.empty_bubble?
  end

  def create
    authorize! ClockifyImport, to: :create?

    unless Current.user.empty_bubble?
      redirect_back fallback_location: new_clockify_import_path,
        alert: t("clockify_imports.create.non_empty_bubble")
      return
    end

    if uploaded_files.empty?
      @empty_bubble = true
      @upload_error = t("clockify_imports.new.form.files_blank")
      render :new, status: :unprocessable_entity
      return
    end

    import = authorized_scope(ClockifyImport.all).create!
    import.files.attach(uploaded_files)
    ClockifyImportJob.perform_later(import)

    redirect_to clockify_import_path(import)
  end

  def show
    @import = authorized_scope(ClockifyImport.all).find(params[:id])
    authorize! @import
    @year_range = imported_year_range(@import) if @import.completed?
  end

  private
    def uploaded_files
      Array(params.dig(:clockify_import, :files)).compact_blank
    end

    def imported_year_range(import)
      started_at = import.user.time_entries.minimum(:started_at)
      ended_at = import.user.time_entries.maximum(:started_at)
      return unless started_at && ended_at

      time_zone = import.user.time_zone
      start_year = started_at.in_time_zone(time_zone).year
      end_year = ended_at.in_time_zone(time_zone).year

      start_year == end_year ? start_year.to_s : "#{start_year}–#{end_year}"
    end
end
