class Report
  # Totais de um conjunto de Rows (Q21/Q43): tempo total, tempo faturável, e amounts
  # POR MOEDA. ⚠️ NUNCA soma moedas diferentes (Q43): `amounts` é um Hash currency =>
  # cents. No fluxo comum (filtrado por 1 cliente) é mono-moeda; a visão "todos" com
  # mix BRL/EUR vira subtotais por moeda no topo.
  class Totals
    attr_reader :duration_seconds, :billable_seconds, :amounts

    def self.from(rows)
      amounts = Hash.new(0)
      rows.each do |row|
        cents = row.amount_cents
        amounts[row.currency] += cents if cents.positive?
      end

      new(
        duration_seconds: rows.sum(&:duration_seconds),
        billable_seconds: rows.sum(&:billable_seconds),
        amounts: amounts
      )
    end

    def initialize(duration_seconds:, billable_seconds:, amounts:)
      @duration_seconds = duration_seconds
      @billable_seconds = billable_seconds
      @amounts = amounts
    end

    # Money por moeda (pra UI formatar). Vazio = nenhum amount faturável no período.
    def money_amounts
      amounts.map { |currency, cents| Money.new(cents, currency) }
    end

    def multiple_currencies?
      amounts.size > 1
    end
  end
end
