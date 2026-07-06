require "test_helper"

# Lógica NOSSA da Task (Fatia 2.3): unicidade de nome POR PROJETO incluindo arquivadas
# (Q44 — mesmo nome em projetos diferentes é OK) e projeto-do-mesmo-user (Q23). Não
# testamos belongs_to/dependent (framework).
class TaskTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
    @project = @user.projects.create!(name: "Projeto")
  end

  # --- Unicidade de nome POR PROJETO, incluindo arquivadas (Q44) ---------------

  test "nome duplicado no mesmo projeto é barrado" do
    @project.tasks.create!(name: "Design", user: @user)
    dup = @project.tasks.build(name: "Design", user: @user)

    assert_not dup.valid?
    assert_includes dup.errors[:name], "já está em uso"
  end

  test "MESMO nome em projetos DIFERENTES é permitido (unicidade por projeto)" do
    outro_projeto = @user.projects.create!(name: "Outro")
    @project.tasks.create!(name: "Design", user: @user)

    assert @user.tasks.build(name: "Design", project: outro_projeto).valid?
  end

  test "nome duplicado colide mesmo com a original ARQUIVADA (Q44)" do
    original = @project.tasks.create!(name: "Design", user: @user)
    original.archive!

    dup = @project.tasks.build(name: "Design", user: @user)
    assert_not dup.valid?
    assert dup.name_conflicts_with_archived?
  end

  # --- Projeto do MESMO user (isolamento Q23) ---------------------------------

  test "task NÃO pode apontar projeto de outra conta" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    task = @user.tasks.build(name: "Invasora", project: alheio)
    assert_not task.valid?
    assert_includes task.errors[:project], "não pertence a você"
  end
end
