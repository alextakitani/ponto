# PORO do relatório (Q58) — o CONTRATO de queries do entregável principal do app.
# NÃO é um Active Record: é um objeto de consulta que orquestra 1 query SQL base +
# um pipeline em Ruby, e expõe `groups`/`rows`/`totals`/`daily_series`.
#
# O SQL faz o recorte base e os filtros de colunas; o Ruby segue responsável por
# rounding, corte de dia no fuso do user (Q6/Q23b — SQLite não tem AT TIME ZONE),
# agrupamento e totais. Volume single-user (um ano ≈ milhares de linhas) torna isso
# trivial (Q58).
#
# Uma estrutura, três consumidores (Q58): Summary (`groups`), Detailed (`rows`,
# started_at DESC), export xlsx/CSV (mesma matriz — Fatia 5.2). Tela e export batem
# por construção.
class Report
  attr_reader :user, :period, :filters, :group_by, :rounding

  def initialize(user:, period:, filters: Filters.none, group_by: nil, rounding: Rounding.off)
    @user = user
    @period = period
    @filters = filters
    @group_by = group_by
    @rounding = rounding
  end

  # Linhas do Detailed (Q19): uma Row por entry, started_at DESC, SEM paginação no 1º
  # corte (volume single-user). Cada Row já carrega a duração/amount arredondados.
  def rows
    @rows ||= pipeline.sort_by { |row| -row.started_at.to_i }
  end

  # Totais do topo (Q21/Q43): tempo, tempo faturável, e amounts POR MOEDA (nunca soma
  # moedas diferentes — Q43).
  def totals
    @totals ||= Totals.from(rows)
  end

  # Série diária pras barras (Q6/Q21): uma barra por DIA do período com as horas do
  # dia (corte no fuso do user). Dias sem entry aparecem com zero (o eixo é o período).
  def daily_series
    @daily_series ||= build_daily_series
  end

  # Grupos do Summary (Q21): agrupamento 1-2 níveis aninhados pela(s) dimensão(ões)
  # de `group_by`. Sem group_by → lista vazia (o Summary cai só nos totais/barras).
  def groups
    @groups ||= Grouping.new(rows: rows, group_by: group_by).groups
  end

  private
    # 1 query SQL base (Q58): bolha do user, SÓ finalizados (Q57), dentro do período,
    # filtros no banco, includes contra N+1. Rounding/corte-de-dia/agrupamento
    # acontecem depois, em Ruby.
    def base_relation
      relation = user.time_entries
        .where.not(ended_at: nil)
        .where(started_at: period.range)
        .includes(:tags, :task, project: :client)
      filters.apply_sql(relation)
    end

    # Pipeline em Ruby: materializa a query e embrulha em Row (aplica rounding por
    # entry). Materializa em array (some N+1 do includes).
    def pipeline
      @pipeline ||= base_relation.to_a
        .map { |entry| Row.new(entry, rounding: rounding, time_zone: time_zone) }
    end

    def build_daily_series
      by_date = rows.group_by(&:date)
      (period.first_date..period.last_date).map do |date|
        rows_for_date = by_date.fetch(date, [])
        totals = Totals.from(rows_for_date)

        DailyBucket.new(
          date: date,
          duration_seconds: totals.duration_seconds,
          first_started_at: rows_for_date.map(&:started_at).min,
          last_ended_at: rows_for_date.map(&:ended_at).max,
          amounts: totals.amounts
        )
      end
    end

    def time_zone
      ActiveSupport::TimeZone[user.time_zone] || Time.zone
    end
end
