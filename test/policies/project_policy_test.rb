require "test_helper"

# A ProjectPolicy herda o piso multi-tenant da ApplicationPolicy (Q23) SEM refinar.
# Verificamos que o herdado se aplica ao Project real: scope filtra pro user do
# contexto e o ownership nega record de outra conta.
class ProjectPolicyTest < ActiveSupport::TestCase
  setup do
    @owner = create_user(email: "owner@example.com")
    @other = create_user(email: "other@example.com")
  end

  test "relation_scope filtra os projects pro user do contexto" do
    mine = @owner.projects.create!(name: "Meu")
    @other.projects.create!(name: "Alheio")

    scoped = ProjectPolicy.new(user: @owner).apply_scope(Project.all, type: :active_record_relation)

    assert_equal [ mine.id ], scoped.pluck(:id)
  end

  test "manage? nega project de outra conta" do
    theirs = @other.projects.create!(name: "Alheio")

    assert_not ProjectPolicy.new(theirs, user: @owner).apply(:manage?)
  end
end
