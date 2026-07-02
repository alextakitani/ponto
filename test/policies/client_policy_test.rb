require "test_helper"

# Lógica nossa: a ClientPolicy herda o piso multi-tenant da ApplicationPolicy
# (Q23/Q40/Q41) SEM refinar. Verificamos que o herdado se aplica ao Client real:
# scope filtra pro user do contexto e o ownership nega record de outra conta.
class ClientPolicyTest < ActiveSupport::TestCase
  setup do
    @owner = create_user(email: "owner@example.com")
    @other = create_user(email: "other@example.com")
  end

  test "relation_scope filtra os clients pro user do contexto" do
    mine = @owner.clients.create!(name: "Meu")
    @other.clients.create!(name: "Alheio")

    scoped = ClientPolicy.new(user: @owner).apply_scope(Client.all, type: :active_record_relation)

    assert_equal [ mine.id ], scoped.pluck(:id)
  end

  test "manage? nega client de outra conta" do
    theirs = @other.clients.create!(name: "Alheio")

    assert_not ClientPolicy.new(theirs, user: @owner).apply(:manage?)
  end
end
