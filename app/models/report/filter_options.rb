class Report
  # Opções dos seletores de filtro (Q54): "o que EXISTE no período", não o catálogo
  # ativo inteiro. Derivadas das rows JÁ carregadas do relatório (sem query nova) —
  # inclui os baldes "(sem projeto)"/"(sem cliente)" quando há entry solto no período.
  #
  # ⚠️ As opções olham o período MAS ignoram os filtros já aplicados de MESMA dimensão
  # seria o ideal (facetado); no 1º corte usamos as rows filtradas (mais simples,
  # single-user). Enriquecimento futuro se incomodar.
  class FilterOptions
    Option = Struct.new(:id, :label, keyword_init: true)

    def initialize(report)
      @rows = report.rows
    end

    def projects
      options_for(
        real: @rows.filter_map(&:project).uniq(&:id).map { |p| Option.new(id: p.id, label: p.name) },
        none_when: @rows.any? { |r| r.project.nil? },
        none_label: "(sem projeto)"
      )
    end

    def clients
      options_for(
        real: @rows.filter_map(&:client).uniq(&:id).map { |c| Option.new(id: c.id, label: c.name) },
        none_when: @rows.any? { |r| r.client.nil? },
        none_label: "(sem cliente)"
      )
    end

    def tasks
      options_for(
        real: @rows.filter_map(&:task).uniq(&:id).map { |t| Option.new(id: t.id, label: t.name) },
        none_when: @rows.any? { |r| r.task.nil? && r.project },
        none_label: "(sem tarefa)"
      )
    end

    def tags
      options_for(
        real: @rows.flat_map(&:tags).uniq(&:id).map { |tag| Option.new(id: tag.id, label: tag.name) },
        none_when: @rows.any? { |row| row.tags.empty? },
        none_label: "(sem tag)"
      )
    end

    private
      def options_for(real:, none_when:, none_label:)
        sorted = real.sort_by { |option| option.label.to_s.downcase }
        sorted << Option.new(id: Filters::NONE, label: none_label) if none_when
        sorted
      end
  end
end
