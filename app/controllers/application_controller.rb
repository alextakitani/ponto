class ApplicationController < ActionController::Base
  include Pagy::Backend

  include Authentication
  include OnboardingGate
  include RequestForgeryProtection
  include ActionPolicy::Controller
  include SetLocale

  # Contexto de autorização do Action Policy (Q40/Q41): a policy raciocina sobre
  # `Current.user`. Autorização negada -> 403 (HTML e JSON) — user comum NÃO vê
  # nada do que a policy protege (ex.: /admin).
  authorize :user, through: :current_user
  rescue_from ActionPolicy::Unauthorized, with: :deny_access

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :command_palette_current_timer, :command_palette_recent_time_entries

  private
    def command_palette_current_timer
      return unless Current.user

      @command_palette_current_timer ||= authorized_scope(TimeEntry.all).find_by(ended_at: nil)
    end

    def command_palette_recent_time_entries
      return TimeEntry.none unless Current.user

      # Dedup por (descrição, projeto) — a mesma tarefa retomada várias vezes
      # aparecia repetida na lista (feedback do dono 07/07). Janela de 25 no SQL,
      # comprime em Ruby e corta em 5.
      @command_palette_recent_time_entries ||= authorized_scope(TimeEntry.all)
        .where.not(ended_at: nil)
        .includes(:project)
        .order(ended_at: :desc, id: :desc)
        .limit(25)
        .uniq { |entry| [ entry.description, entry.project_id ] }
        .first(5)
    end

    def deny_access
      respond_to do |format|
        format.html { render "shared/forbidden", status: :forbidden }
        format.json { render json: { error: t("errors.forbidden") }, status: :forbidden }
      end
    end
end
