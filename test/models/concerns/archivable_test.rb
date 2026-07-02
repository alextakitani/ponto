require "test_helper"

# Lógica nossa: soft delete via `archived_at` (Q7). Sem tabela de domínio ainda —
# uma tabela efêmera + model anônimo exercitam o concern diretamente.
class ArchivableTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :archivable_test_models, temporary: true, force: true do |t|
      t.datetime :archived_at
    end

    @model = Class.new(ApplicationRecord) do
      self.table_name = "archivable_test_models"
      include Archivable
    end
  end

  teardown do
    @connection.drop_table :archivable_test_models, if_exists: true
  end

  test "archive! carimba archived_at e vira arquivado" do
    record = @model.create!

    assert record.active?
    assert_not record.archived?

    record.archive!

    assert record.archived?
    assert_not record.active?
    assert record.archived_at.present?
  end

  test "unarchive! zera archived_at e reativa" do
    record = @model.create!(archived_at: Time.current)
    assert record.archived?

    record.unarchive!

    assert record.active?
    assert_nil record.archived_at
  end

  test "archive! é idempotente: não recarimba o timestamp original" do
    record = @model.create!
    record.archive!
    original = record.archived_at

    travel 1.hour do
      record.archive!
    end

    assert_equal original, record.reload.archived_at
  end

  test "scope archived só traz os arquivados" do
    active = @model.create!
    archived = @model.create!(archived_at: Time.current)

    assert_equal [ archived.id ], @model.archived.pluck(:id)
    assert_not_includes @model.archived.pluck(:id), active.id
  end

  test "scope active só traz os não-arquivados" do
    active = @model.create!
    archived = @model.create!(archived_at: Time.current)

    assert_equal [ active.id ], @model.active.pluck(:id)
    assert_not_includes @model.active.pluck(:id), archived.id
  end

  test "sem default_scope: unscoped padrão enxerga arquivados e ativos" do
    @model.create!
    @model.create!(archived_at: Time.current)

    assert_equal 2, @model.count
  end
end
