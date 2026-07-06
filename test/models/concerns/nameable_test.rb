require "test_helper"

class NameableTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  test "normaliza nome com downcase e remoção de acentos" do
    client = @user.clients.create!(name: "Ácaro")

    assert_equal "acaro", client.name_normalized
    assert_equal "kube", Client.normalize_name("Kube")
  end

  test "alphabetical ordena pela forma normalizada" do
    @user.clients.create!(name: "zeta")
    @user.clients.create!(name: "Ácaro")
    @user.clients.create!(name: "Beta")

    assert_equal [ "Ácaro", "Beta", "zeta" ], @user.clients.alphabetical.map(&:name)
  end

  test "name_matching busca sem diferenciar caso ou acento" do
    @user.clients.create!(name: "Padaria do João")
    @user.clients.create!(name: "Mercado Central")

    assert_equal [ "Padaria do João" ], @user.clients.name_matching("joao").to_a.map(&:name)
    assert_equal [ "Padaria do João" ], @user.clients.name_matching("PADÁ").to_a.map(&:name)
  end

  test "name_matching escapa curingas de LIKE" do
    literal = @user.clients.create!(name: "100% Real")
    @user.clients.create!(name: "1000 Real")

    assert_equal [ literal ], @user.clients.name_matching("100%").to_a
  end

  test "unicidade usa nome normalizado no mesmo escopo" do
    @user.clients.create!(name: "Kube")

    duplicate = @user.clients.build(name: "kube")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "já está em uso"
  end

  test "task usa project_id como escopo de unicidade normalizada" do
    first = @user.projects.create!(name: "Primeiro")
    second = @user.projects.create!(name: "Segundo")
    first.tasks.create!(name: "Ácaro", user: @user)

    assert first.tasks.build(name: "acaro", user: @user).invalid?
    assert second.tasks.build(name: "acaro", user: @user).valid?
  end
end
