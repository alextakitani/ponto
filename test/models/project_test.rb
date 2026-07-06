require "test_helper"

# Lógica NOSSA do Project (Fatia 2.3): rate efetiva com override/herança (Q22), cor
# da paleta fixa + auto-atribuição da menos-usada (Q52), unicidade por user incluindo
# arquivados (Q44) e cliente-do-mesmo-user (Q23). Não testamos
# belongs_to/monetize/dependent (framework/gem).
class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  # --- Rate efetiva: 4 casos (Q22) --------------------------------------------

  test "rate efetiva usa o OVERRIDE do projeto quando presente" do
    client = @user.clients.create!(name: "Acme", currency: "BRL", rate_cents: 10000)
    project = @user.projects.create!(name: "P1", client: client, rate_cents: 20000)

    assert_equal 20000, project.effective_rate_cents
    assert_equal "BRL", project.effective_currency
    assert_not project.rate_inherited?
  end

  test "rate efetiva HERDA a do cliente quando o override é nulo" do
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 15000)
    project = @user.projects.create!(name: "P1", client: client)

    assert_equal 15000, project.effective_rate_cents
    assert_equal "USD", project.effective_currency
    assert project.rate_inherited?
  end

  test "rate efetiva é NIL sem override e sem rate do cliente" do
    client = @user.clients.create!(name: "SemTaxa", currency: "BRL") # rate_cents nil
    project = @user.projects.create!(name: "P1", client: client)

    assert_nil project.effective_rate_cents
    assert_nil project.effective_currency
    assert_not project.rate_inherited?
  end

  test "projeto SEM cliente COM rate própria usa BRL default (moeda mora no cliente)" do
    project = @user.projects.create!(name: "Avulso", rate_cents: 12345)

    assert_equal 12345, project.effective_rate_cents
    assert_equal "BRL", project.effective_currency
    assert_not project.rate_inherited?
  end

  # --- Cor: formato + auto-atribuição da menos-usada (Q52) ---------------------

  test "cor fora do formato hex #RRGGBB é inválida" do
    project = @user.projects.new(name: "Cor", color: "vermelho")
    assert_not project.valid?
    assert_includes project.errors[:color], "não é uma cor válida"
  end

  test "cor da paleta é aceita" do
    project = @user.projects.new(name: "Cor", color: Project::PALETTE.first)
    project.valid?
    assert_empty project.errors[:color]
  end

  test "cor auto-atribuída no create é a PRIMEIRA da paleta quando não há projetos" do
    project = @user.projects.create!(name: "Primeiro")
    assert_equal Project::PALETTE.first, project.color
  end

  test "cor auto-atribuída pula as já usadas (escolhe a menos usada)" do
    @user.projects.create!(name: "A") # pega PALETTE[0]
    @user.projects.create!(name: "B") # PALETTE[0] agora usada → pega PALETTE[1]

    terceiro = @user.projects.create!(name: "C") # PALETTE[2]
    assert_equal Project::PALETTE[2], terceiro.color
  end

  test "cor auto-atribuída IGNORA projetos arquivados na contagem" do
    a = @user.projects.create!(name: "A")   # PALETTE[0]
    a.archive!                               # arquivado não conta

    novo = @user.projects.create!(name: "B") # PALETTE[0] volta a ser a menos-usada
    assert_equal Project::PALETTE[0], novo.color
  end

  test "cor explícita no create NÃO é sobrescrita pela auto-atribuição" do
    escolhida = Project::PALETTE.last
    project = @user.projects.create!(name: "Escolhida", color: escolhida)
    assert_equal escolhida, project.color
  end

  # --- Unicidade de nome por user, incluindo arquivados (Q44) ------------------

  test "nome duplicado no mesmo user é barrado" do
    @user.projects.create!(name: "Site")
    dup = @user.projects.build(name: "Site")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "já está em uso"
  end

  test "nome duplicado colide mesmo com o original ARQUIVADO (Q44)" do
    original = @user.projects.create!(name: "Site")
    original.archive!

    dup = @user.projects.build(name: "Site")
    assert_not dup.valid?
    assert dup.name_conflicts_with_archived?
  end

  test "users diferentes podem repetir o mesmo nome de projeto" do
    @user.projects.create!(name: "Site")
    outro = create_user(email: "outro@example.com")
    assert outro.projects.build(name: "Site").valid?
  end

  # --- Cliente do MESMO user (isolamento Q23) ---------------------------------

  test "projeto NÃO pode apontar cliente de outra conta" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.clients.create!(name: "Alheio")

    project = @user.projects.build(name: "Invasor", client: alheio)
    assert_not project.valid?
    assert_includes project.errors[:client], "não pertence a você"
  end

  test "projeto sem cliente é válido (Q2)" do
    assert @user.projects.build(name: "Avulso").valid?
  end
end
