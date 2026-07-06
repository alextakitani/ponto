require "test_helper"

# Lógica NOSSA do Report::Filters: o predicado any? decide se o botão Filtros
# acende (filtro de DADOS aplicado). Agrupamento/rounding são formatação e NÃO contam.
class Report::FiltersTest < ActiveSupport::TestCase
  test "none? não tem filtro aplicado" do
    assert_not Report::Filters.none.any?
  end

  test "qualquer dimensão de dados marca any?" do
    assert Report::Filters.new(client_ids: [ "1" ]).any?
    assert Report::Filters.new(project_ids: [ "2" ]).any?
    assert Report::Filters.new(task_ids: [ "3" ]).any?
    assert Report::Filters.new(tag_ids: [ "4" ]).any?
    assert Report::Filters.new(billable: true).any?
    assert Report::Filters.new(billable: false).any?
    assert Report::Filters.new(description: "algo").any?
  end

  test "ids/descrição em branco não marcam any?" do
    assert_not Report::Filters.new(client_ids: [ "", nil ], description: "  ").any?
  end
end
