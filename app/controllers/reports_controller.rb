# Relatórios (Fatia 5.1) — o entregável principal. Controller FINO: traduz os params
# da URL nos value objects do Report (Period/Filters/Rounding) e monta o PORO, que faz
# todo o trabalho pesado (STYLE.md — modelo rico, sem service layer). Uma tela, duas
# abas (Summary/Detailed) via param `view`; tudo o mais viaja na URL (pra 5.2 herdar
# no export e pro link ser compartilhável).
class ReportsController < ApplicationController
  layout "app"

  def index
    authorize! Report, to: :index?

    @view = params[:view] == "detailed" ? "detailed" : "summary"
    @period = build_period
    @report = Report.new(
      user: Current.user,
      period: @period,
      filters: build_filters,
      group_by: group_by_params,
      rounding: build_rounding
    )
    # Opções de filtro/dimensão = o que EXISTE no período (Q54) — derivadas do próprio
    # relatório (rows já materializadas) pra não abrir query nova.
    @filter_options = report_filter_options
  end

  private
    # Período (Q53): preset + navegação por setas. A seta manda `nav=prev|next` sobre o
    # período corrente; o controller resolve o passo (o Period sabe o tamanho). Custom
    # carrega `from`/`to`. Bordas SEMPRE no fuso do user (Q23b) — passado ao Period.
    def build_period
      period = Report::Period.new(
        preset: params[:period].presence || Report::Period::DEFAULT_PRESET,
        from: parse_date(params[:from]),
        to: parse_date(params[:to]),
        today: today_in_zone,
        time_zone: Current.user.time_zone
      )

      case params[:nav]
      when "prev" then period.previous
      when "next" then period.next
      else period
      end
    end

    def build_filters
      Report::Filters.new(
        client_ids: Array(params[:client_ids]),
        project_ids: Array(params[:project_ids]),
        task_ids: Array(params[:task_ids]),
        billable: billable_param,
        description: params[:description]
      )
    end

    # Rounding (Q56): OFF por padrão. `rounding=on` liga; block/direction opcionais.
    def build_rounding
      return Report::Rounding.off unless params[:rounding] == "on"

      Report::Rounding.new(
        block: params[:rounding_block].presence || Report::Rounding::DEFAULT_BLOCK,
        direction: params[:rounding_direction].presence || Report::Rounding::DEFAULT_DIRECTION
      )
    end

    # group_by: 1-2 níveis (Q21). Dois selects escalares (nível 1 = group_by, nível 2 =
    # group_by_2) montam a lista aninhada — evita o conflito de escalar+array no mesmo
    # nome de param. Vazio → sem agrupamento; nível 2 sem nível 1 é ignorado.
    def group_by_params
      [ params[:group_by], params[:group_by_2] ]
        .map(&:to_s).reject(&:blank?).uniq.first(2)
    end

    # billable: "true"/"false"/vazio → true/false/nil (todos).
    def billable_param
      case params[:billable]
      when "true"  then true
      when "false" then false
      end
    end

    def report_filter_options
      Report::FilterOptions.new(@report)
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def today_in_zone
      zone = ActiveSupport::TimeZone[Current.user.time_zone] || Time.zone
      Time.current.in_time_zone(zone).to_date
    end
end
