require "test_helper"

# Lógica nossa: o piso de autorização multi-tenant (Q23/Q40/Q41). Toda policy de
# domínio herda daqui — o `relation_scope` filtra pro user do contexto (isolamento
# por bolha) e o ownership base nega record de outra conta. Tabela efêmera + model
# anônimo exercitam a policy sem depender de nenhuma tabela de domínio ainda.
class ApplicationPolicyTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :tenant_test_models, temporary: true, force: true do |t|
      t.integer :user_id
    end

    @model = Class.new(ApplicationRecord) do
      self.table_name = "tenant_test_models"
      belongs_to :user

      def self.name = "TenantTestModel"
    end

    @owner = create_user(email: "owner@example.com")
    @other = create_user(email: "other@example.com")
    @policy = Class.new(ApplicationPolicy) do
      def self.name = "TenantTestModelPolicy"
    end
  end

  teardown do
    @connection.drop_table :tenant_test_models, if_exists: true
  end

  test "relation_scope filtra os records pro user do contexto" do
    mine = @model.create!(user: @owner)
    @model.create!(user: @other)

    scoped = @policy.new(user: @owner).apply_scope(@model.all, type: :active_record_relation)

    assert_equal [ mine.id ], scoped.pluck(:id)
  end

  test "relation_scope vazio quando o user do contexto não tem records" do
    @model.create!(user: @other)

    scoped = @policy.new(user: @owner).apply_scope(@model.all, type: :active_record_relation)

    assert_empty scoped
  end

  test "manage? permite o dono do record" do
    mine = @model.create!(user: @owner)

    assert @policy.new(mine, user: @owner).apply(:manage?)
  end

  test "manage? nega record de outra conta" do
    theirs = @model.create!(user: @other)

    assert_not @policy.new(theirs, user: @owner).apply(:manage?)
  end
end
