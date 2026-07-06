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

  test "nome duplicado com caixa diferente é barrado" do
    @user.tags.create!(name: "Urgente")

    duplicate = @user.tags.build(name: "urgente")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "já está em uso"
  end
end
