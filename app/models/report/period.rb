class Report
  # Janela de tempo do relatório (Q53). Presets enxutos + custom; as setas ‹ › andam
  # pelo TAMANHO do período. As bordas são calculadas SEMPRE no fuso do user (Q23b/Q6),
  # NÃO na constante global `config.time_zone` — por isso o `time_zone` é injetado e o
  # `range` é montado com `zone.local(...)`, comparável direto contra `started_at`.
  #
  # Internamente o Period é só um par de DATAS (first_date..last_date) + o fuso. Os
  # presets são atalhos que derivam esse par de `today`; custom recebe o par direto.
  # As setas devolvem um NOVO Period deslocado pelo tamanho da janela (imutável).
  class Period
    PRESETS = %w[today week month year custom].freeze
    DEFAULT_PRESET = "month"
    DEFAULT_TIME_ZONE = "America/Sao_Paulo"

    attr_reader :preset, :first_date, :last_date

    def initialize(preset: DEFAULT_PRESET, today: Date.current, from: nil, to: nil, time_zone: DEFAULT_TIME_ZONE)
      @preset = PRESETS.include?(preset) ? preset : DEFAULT_PRESET
      @time_zone = time_zone
      @zone = ActiveSupport::TimeZone[time_zone] || Time.zone

      if @preset == "custom"
        @first_date, @last_date = resolve_custom(from, to, today)
      else
        @first_date = preset_first(today)
        @last_date  = preset_last(today)
      end
    end

    # Intervalo [início 00:00, fim 23:59:59.999…] no fuso do user. `started_at` (UTC
    # no banco) cai dentro por comparação de instantes — o ActiveSupport::TimeZone
    # resolve o offset (inclusive DST) do fuso do user.
    def range
      first_date.in_time_zone(@zone).beginning_of_day..last_date.in_time_zone(@zone).end_of_day
    end

    # Setas ‹ › (Q53): recuam/avançam pelo TAMANHO da janela. Preset nomeado anda por
    # unidade de calendário (mês→mês, semana→semana, ano→ano, dia→dia); custom anda
    # pelo mesmo número de dias. Sempre devolve um Period CUSTOM ancorado nas datas
    # deslocadas (o preset nomeado vira custom ao navegar — evita "mês curto → mês
    # seguinte pula" e mantém o tamanho estável).
    def previous
      shift(-1)
    end

    def next
      shift(+1)
    end

    # Data-âncora que os presets nomeados usam pra recalcular a janela ao navegar —
    # um dia DENTRO do período seguinte. Preservar o preset (em vez de virar custom)
    # deixa a UI rotular "junho 2026" limpo em vez de "01/06 – 30/06".

    def custom?
      @preset == "custom"
    end

    private
      def shift(direction)
        case @preset
        when "today"
          reanchored(first_date + direction)
        when "week"
          reanchored(first_date + direction * 7)
        when "month"
          reanchored(first_date.advance(months: direction))
        when "year"
          reanchored(first_date.advance(years: direction))
        when "custom"
          span = (last_date - first_date).to_i + 1
          shifted(first_date + direction * span, last_date + direction * span)
        end
      end

      # Presets nomeados: reconstroem-se a partir de uma nova âncora `today` dentro da
      # janela deslocada — assim o preset é PRESERVADO e o mês curto→longo re-ancora
      # nas bordas do calendário sozinho (junho tem 30, julho 31).
      def reanchored(new_anchor)
        Period.new(preset: @preset, today: new_anchor, time_zone: @time_zone)
      end

      # Custom não tem calendário: desloca as duas datas cruas e continua custom.
      def shifted(new_first, new_last)
        Period.new(preset: "custom", from: new_first, to: new_last, time_zone: @time_zone)
      end

      def resolve_custom(from, to, today)
        first = from || today
        last  = to || today
        first, last = last, first if last < first # tolera datas invertidas do form
        [ first, last ]
      end

      def preset_first(today)
        case @preset
        when "today" then today
        when "week"  then today.beginning_of_week # segunda-feira, fixo (Q53)
        when "month" then today.beginning_of_month
        when "year"  then today.beginning_of_year
        end
      end

      def preset_last(today)
        case @preset
        when "today" then today
        when "week"  then today.end_of_week
        when "month" then today.end_of_month
        when "year"  then today.end_of_year
        end
      end
  end
end
