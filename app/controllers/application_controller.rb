class ApplicationController < ActionController::Base
  include Pagy::Backend

  include Authentication
  include Ahoy::Controller
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

  # Não cria "visita" (ahoy_visits) para acessos de API (CLI/extensão via Bearer):
  # eles não são navegação de browser, e o Ahoy geraria uma visita órfã por
  # request (sem browser/referrer, cookie de token ignorado). O USO da API é
  # rastreado como evento `api_request` no after_action abaixo. Ver
  # docs/adr/analytics-tracking.md.
  skip_before_action :track_ahoy_visit, if: :api_client_request?

  after_action :track_analytics_event

  helper_method :command_palette_current_timer, :command_palette_recent_time_entries

  private
    def current_ahoy_user
      Current.user
    end

    # Acesso de máquina (CLI/extensão): Bearer + formato não-HTML (json/csv/xlsx).
    def api_client_request?
      request.authorization.to_s.include?("Bearer") &&
        (request.format.json? || request.format.csv? || request.format.xlsx?)
    end

    # Navegação de browser -> evento `$view` (páginas/rotas no dashboard).
    # Acesso de API -> evento `api_request` (uso de endpoints, SEM virar visita).
    # Os dois carimbam user_id quando há sessão/token (Current.user), como dado
    # operacional do admin (exceção consciente ao Q23 — ver ADR).
    def track_analytics_event
      if api_client_request?
        track_api_request
      elsif request.get? && request.format.html?
        ahoy.authenticate(current_ahoy_user) if current_ahoy_user
        ahoy.track "$view", controller: controller_name, action: action_name, url: request.path
      end
    end

    # `ahoy.track` NÃO serve pra API: o DatabaseStore descarta qualquer evento
    # sem visita ("Event excluded since visit not created"), e nós de propósito
    # não criamos visita pra acesso de máquina. Então gravamos o evento direto,
    # com visit_id nulo — é justamente o que queremos (uso de endpoint, não visita).
    def track_api_request
      Ahoy::Event.create!(
        user_id: current_ahoy_user&.id,
        name: "api_request",
        properties: {
          controller: controller_name, action: action_name,
          method: request.request_method, format: request.format.to_sym.to_s
        }.to_json,
        time: Time.current
      )
    end

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
