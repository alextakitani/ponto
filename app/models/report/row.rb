class Report
  # Uma linha do relatório = um TimeEntry decorado com os valores JÁ arredondados
  # (Q56) e o dia no fuso do user (Q6). É a unidade que o Detailed lista, o Summary
  # agrupa e os totais somam — garantindo que as três visões batam por construção.
  #
  # Rounding é SÓ LEITURA (Q56): `duration_seconds` aqui é a duração arredondada e
  # `amount_cents` recalcula `horas_arredondadas × rate` (ROUND_HALF_UP no centavo —
  # Q11/Q18). O snapshot gravado no entry (rate_cents/currency/started_at) fica intacto.
  class Row
    attr_reader :entry, :duration_seconds

    def initialize(entry, rounding:, time_zone:)
      @entry = entry
      @time_zone = time_zone
      @duration_seconds = rounding.round_seconds(entry.duration_seconds.to_i)
    end

    def started_at = entry.started_at
    def ended_at = entry.ended_at
    def description = entry.description
    def project = entry.project
    def task = entry.task
    def client = entry.project&.client
    def billable? = entry.billable?
    def rate_cents = entry.rate_cents
    def currency = entry.currency

    # Dia ao qual o entry pertence INTEIRO (Q6): started_at no fuso do user → data.
    def date
      @date ||= entry.started_at.in_time_zone(@time_zone).to_date
    end

    # Faturável (Q18): billable=true E rate presente. Marcar não-faturável zera o
    # amount mas MANTÉM as horas (que continuam em duration_seconds).
    def billable_seconds
      billable_amount? ? duration_seconds : 0
    end

    # Amount recalculado sobre a duração ARREDONDADA (Q56): horas × rate, arredondando
    # no centavo com ROUND_HALF_UP (Q11). Zero quando não faturável.
    def amount_cents
      return 0 unless billable_amount?

      hours = BigDecimal(duration_seconds.to_s) / 3600
      (BigDecimal(rate_cents.to_s) * hours).round(0, BigDecimal::ROUND_HALF_UP).to_i
    end

    private
      def billable_amount?
        entry.billable? && !entry.rate_cents.nil?
      end
  end
end
