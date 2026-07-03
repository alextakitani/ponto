require "test_helper"

class TagPolicyTest < ActiveSupport::TestCase
  setup do
    @owner = create_user(email: "owner@example.com")
    @other = create_user(email: "other@example.com")
  end

  test "relation_scope filtra as tags pro user do contexto" do
    mine = @owner.tags.create!(name: "Minha")
    @other.tags.create!(name: "Alheia")

    scoped = TagPolicy.new(user: @owner).apply_scope(Tag.all, type: :active_record_relation)

    assert_equal [ mine.id ], scoped.pluck(:id)
  end

  test "manage? nega tag de outra conta" do
    theirs = @other.tags.create!(name: "Alheia")

    assert_not TagPolicy.new(theirs, user: @owner).apply(:manage?)
  end
end
