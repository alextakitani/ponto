require "test_helper"

class TagTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  test "nome é único por user inclusive quando a tag está arquivada" do
    original = @user.tags.create!(name: "Urgente")
    original.archive!

    duplicate = @user.tags.build(name: "Urgente")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "já está em uso"
    assert duplicate.name_conflicts_with_archived?
  end

  test "mesmo nome pode existir em users diferentes" do
    @user.tags.create!(name: "Urgente")
    other = create_user(email: "outro@example.com")

    assert other.tags.build(name: "Urgente").valid?
  end

  test "nome não fica em claro no SQL cru" do
    @user.tags.create!(name: "Segredo")

    raw = ActiveRecord::Base.connection.select_value("SELECT name FROM tags LIMIT 1")
    assert_not_nil raw
    assert_not_includes raw, "Segredo"
  end
end
