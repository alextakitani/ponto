class Report
  # Uma barra do gráfico "horas por DIA" (Q6/Q21). Materializa a Q6: cada entry cai
  # inteiro no dia do started_at (no fuso do user), e o eixo é o período completo
  # (dias sem entry aparecem com zero). O partial SVG das barras consome isto.
  class DailyBucket
    attr_reader :date, :duration_seconds

    def initialize(date:, duration_seconds:)
      @date = date
      @duration_seconds = duration_seconds
    end

    def hours
      duration_seconds / 3600.0
    end
  end
end
