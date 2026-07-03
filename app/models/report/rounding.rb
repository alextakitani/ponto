class Report
  # Arredondamento POR ENTRY (Q56). SÓ LEITURA: recalcula a duração exibida (e, por
  # consequência, o amount = horas_arredondadas × rate) — NUNCA toca started_at/
  # ended_at/snapshot gravados (Q10/Q11 intactas). Por entry (não por grupo) pra
  # Detailed bater com Summary/export em qualquer group-by.
  #
  # Bloco: 5/15/30 min (default 15). Direção: cima/próximo/baixo (default próximo).
  # OFF por padrão (o xlsx real é exato; feature opcional que viaja na URL).
  class Rounding
    BLOCKS = [ 5, 15, 30 ].freeze
    DEFAULT_BLOCK = 15
    DIRECTIONS = %w[up nearest down].freeze
    DEFAULT_DIRECTION = "nearest"

    attr_reader :block, :direction

    def self.off
      new(enabled: false)
    end

    def initialize(block: DEFAULT_BLOCK, direction: DEFAULT_DIRECTION, enabled: true)
      @enabled = enabled
      @block = BLOCKS.include?(block.to_i) ? block.to_i : DEFAULT_BLOCK
      @direction = DIRECTIONS.include?(direction.to_s) ? direction.to_s : DEFAULT_DIRECTION
    end

    def on?
      @enabled
    end

    # Arredonda `seconds` pro bloco escolhido na direção escolhida. OFF passa reto.
    def round_seconds(seconds)
      return seconds.to_i unless on?

      block_seconds = @block * 60
      quotient = seconds.to_f / block_seconds

      blocks =
        case @direction
        when "up"      then quotient.ceil
        when "down"    then quotient.floor
        else                quotient.round # nearest (empate .5 → cima, comportamento do Float#round)
        end

      blocks * block_seconds
    end
  end
end
