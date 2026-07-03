class Report
  # Agrupamento 1-2 níveis ANINHADOS do Summary (Q21). Dimensões: Project/Client/Task/
  # Description (Tag depois — fase Tags). Cada Group carrega seus totais (duração,
  # tempo faturável, subtotais por moeda — Q43) e, se houver 2º nível, seus subgroups.
  # Baldes "(sem X)" explícitos. Ordenação por duração desc (maior primeiro).
  #
  # Roda em Ruby sobre Rows já decriptadas/arredondadas (Q58) — GROUP BY no banco não
  # serve (nomes/description criptografados — Q25).
  class Grouping
    # Dimensões suportadas → como extrair a chave de agrupamento de uma Row. A chave é
    # um par [valor_de_ordenação_estável, título_exibido]; nil vira o balde "(sem X)".
    DIMENSIONS = {
      "project"     => ->(row) { row.project&.name },
      "client"      => ->(row) { row.client&.name },
      "task"        => ->(row) { row.task&.name },
      "description" => ->(row) { row.description.presence }
    }.freeze

    EMPTY_LABELS = {
      "project"     => "(sem projeto)",
      "client"      => "(sem cliente)",
      "task"        => "(sem tarefa)",
      "description" => "(sem descrição)"
    }.freeze

    def initialize(rows:, group_by:)
      @rows = rows
      @dimensions = Array(group_by).map(&:to_s).select { |d| DIMENSIONS.key?(d) }.first(2)
    end

    def groups
      return [] if @dimensions.empty?

      build(@rows, @dimensions)
    end

    private
      # Agrupa `rows` pela 1ª dimensão de `dims`; se sobrar dimensão, recursivamente
      # subdivide cada grupo. Ordena por duração desc.
      def build(rows, dims)
        dimension, *rest = dims
        label = EMPTY_LABELS.fetch(dimension)
        extractor = DIMENSIONS.fetch(dimension)

        rows
          .group_by { |row| extractor.call(row) || label }
          .map do |title, group_rows|
            subgroups = rest.any? ? build(group_rows, rest) : []
            Group.new(title: title, rows: group_rows, subgroups: subgroups)
          end
          .sort_by { |group| -group.duration_seconds }
      end

    # Um nó da árvore de agrupamento. Soma seus Rows (ou herda dos subgroups — dá no
    # mesmo, os rows do pai são a união dos filhos).
    class Group
      attr_reader :title, :subgroups

      def initialize(title:, rows:, subgroups: [])
        @title = title
        @rows = rows
        @subgroups = subgroups
      end

      def count
        @rows.size
      end

      def duration_seconds
        @rows.sum(&:duration_seconds)
      end

      def billable_seconds
        @rows.sum(&:billable_seconds)
      end

      # Subtotais por moeda (Q43): Hash currency => cents, nunca somando moedas.
      def amounts
        @amounts ||= @rows.each_with_object(Hash.new(0)) do |row, acc|
          cents = row.amount_cents
          acc[row.currency] += cents if cents.positive?
        end
      end

      def money_amounts
        amounts.map { |currency, cents| Money.new(cents, currency) }
      end
    end
  end
end
