class Report
  # Filtros finos (Q54): 6 dimensões, OR dentro da dimensão / AND entre dimensões.
  # Value object imutável montado dos params. Os filtros por ID (client/project/task)
  # e billable rodam no SQL (baratos, colunas em claro); Description roda em Ruby
  # (coluna criptografada — Q25). Tag fica preparada mas NÃO implementada (fase Tags).
  #
  # Baldes "(sem X)": o sentinela `NONE` numa lista de ids significa "inclua os sem
  # projeto/cliente" — filtrável junto com ids reais (Q2/Q15).
  class Filters
    NONE = "none" # sentinela do balde "(sem projeto)"/"(sem cliente)"

    attr_reader :client_ids, :project_ids, :task_ids, :tag_ids, :billable, :description

    def self.none
      new
    end

    # Há algum filtro de DADOS aplicado? (as 6 dimensões que reduzem o conjunto —
    # não conta agrupamento/rounding, que são formatação, não filtro). Usado pra
    # sinalizar visualmente "filtro ativo" no botão Filtros.
    def any?
      client_ids.any? || project_ids.any? || task_ids.any? || tag_ids.any? ||
        !billable.nil? || description.present?
    end

    def initialize(client_ids: [], project_ids: [], task_ids: [], tag_ids: [], billable: nil, description: nil)
      @client_ids = Array(client_ids).map(&:to_s).reject(&:blank?)
      @project_ids = Array(project_ids).map(&:to_s).reject(&:blank?)
      @task_ids = Array(task_ids).map(&:to_s).reject(&:blank?)
      @tag_ids = Array(tag_ids).map(&:to_s).reject(&:blank?)
      # billable: nil = todos, true = só faturável, false = só não-faturável (Q54).
      @billable = billable
      @description = description.to_s.strip.presence
    end

    # Aplica no SQL os filtros que SÃO seguros no banco (ids em claro + billable).
    # Client é join em projects; os baldes "(sem X)" viram OR ... IS NULL.
    def apply_sql(relation)
      relation = filter_by_ids(relation, :project_id, @project_ids)
      relation = filter_by_ids(relation, :task_id, @task_ids)
      relation = filter_by_client(relation, @client_ids)
      relation = filter_by_tag(relation, @tag_ids)
      relation = relation.where(billable: @billable) unless @billable.nil?
      relation
    end

    # Description contains, case-insensitive, EM RUBY (decrypt já rodou no load).
    # Sem termo → passa reto.
    def description_match?(entry)
      return true if @description.blank?

      entry.description.to_s.downcase.include?(@description.downcase)
    end

    private
      def filter_by_ids(relation, column, ids)
        return relation if ids.empty?

        real_ids = ids.reject { |id| id == NONE }
        wants_none = ids.include?(NONE)
        # Coluna via Arel (não interpolação de string) — injection-proof: o Arel monta
        # o SQL com o nome da coluna citado corretamente. `col` é da própria TimeEntry.
        col = TimeEntry.arel_table[column]

        if wants_none && real_ids.any?
          relation.where(col.in(real_ids).or(col.eq(nil)))
        elsif wants_none
          relation.where(column => nil)
        else
          relation.where(column => real_ids)
        end
      end

      def filter_by_client(relation, ids)
        return relation if ids.empty?

        real_ids = ids.reject { |id| id == NONE }
        wants_none = ids.include?(NONE) # "(sem cliente)" = projeto sem client OU sem projeto

        # LEFT JOIN pra alcançar projects.client_id sem perder entries sem projeto.
        joined = relation.left_joins(:project)
        client_col = Project.arel_table[:client_id]

        if wants_none && real_ids.any?
          joined.where(client_col.in(real_ids).or(client_col.eq(nil)))
        elsif wants_none
          joined.where(client_col.eq(nil))
        else
          joined.where(projects: { client_id: real_ids })
        end
      end

      def filter_by_tag(relation, ids)
        return relation if ids.empty?

        real_ids = ids.reject { |id| id == NONE }
        wants_none = ids.include?(NONE)

        tagged = relation.where(id: Tagging.where(tag_id: real_ids).select(:time_entry_id)) if real_ids.any?
        untagged = relation.where.missing(:taggings) if wants_none

        if tagged && untagged
          relation.where(id: tagged.select(:id)).or(relation.where(id: untagged.select(:id)))
        elsif tagged
          tagged
        else
          untagged
        end
      end
  end
end
