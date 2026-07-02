require "test_helper"

# Lógica NOSSA do TimeEntry (Fatia 3.1): invariantes de tempo, snapshot de rate,
# integridade task↔project, default de billable, cálculo faturável, descarte de
# duração-zero, isolamento por user e criptografia da descrição. Não testamos
# belongs_to/monetize/dependent (framework/gem).
class TimeEntryTest < ActiveSupport::TestCase
  setup do
    @user = create_user(email: "dono@example.com")
  end

  test "entry rodando é válida e entry finalizada exige ended_at maior que started_at" do
    started_at = Time.current
    running = @user.time_entries.build(started_at: started_at)
    assert running.valid?, running.errors.full_messages.to_sentence

    invalid = @user.time_entries.build(started_at: started_at, ended_at: started_at)
    assert_not invalid.valid?
    assert_includes invalid.errors[:ended_at], "deve ser maior que o início"
  end

  test "snapshot congela a rate efetiva e não revaloriza histórico" do
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 15000)
    project = @user.projects.create!(name: "Site", client: client)
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    assert_equal 15000, entry.rate_cents
    assert_equal "USD", entry.currency

    client.update!(rate_cents: 30000)
    entry.reload

    assert_equal 15000, entry.rate_cents
    assert_equal "USD", entry.currency
  end

  test "editar outro campo do entry após mudança de rate NÃO revaloriza o snapshot" do
    # Guarda a invariante Q10: o snapshot só recarimba quando project_id muda.
    # Sem project_id mudando, salvar o entry (editar descrição) deve preservar
    # rate/moeda congeladas mesmo que a rate do cliente tenha mudado no meio.
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 15000)
    project = @user.projects.create!(name: "Site", client: client)
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    client.update!(rate_cents: 99999)
    entry.update!(description: "descrição editada depois do reajuste")
    entry.reload

    assert_equal 15000, entry.rate_cents
    assert_equal "USD", entry.currency
  end

  test "billable_amount arredonda no centavo com ROUND_HALF_UP" do
    client = @user.clients.create!(name: "Meia", currency: "BRL", rate_cents: 1)
    project = @user.projects.create!(name: "Fração", client: client)
    started_at = Time.current - 30.minutes # 0,5h × 1 centavo = 0,5 centavo → 1 (half-up)
    entry = @user.time_entries.create!(project: project, started_at:, ended_at: Time.current)

    assert_equal 1, entry.billable_amount.cents
  end

  test "snapshot recarimba quando o projeto muda e usa BRL sem projeto/rate" do
    client = @user.clients.create!(name: "Acme", currency: "EUR", rate_cents: 12000)
    first_project = @user.projects.create!(name: "A", client: client)
    second_project = @user.projects.create!(name: "B", rate_cents: 23000)
    entry = @user.time_entries.create!(
      project: first_project,
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    entry.update!(project: second_project)
    assert_equal 23000, entry.rate_cents
    assert_equal "BRL", entry.currency

    entry.update!(project: nil)
    assert_nil entry.rate_cents
    assert_equal "BRL", entry.currency
  end

  test "projeto deve pertencer ao mesmo user" do
    outro = create_user(email: "outro@example.com")
    alheio = outro.projects.create!(name: "Alheio")

    entry = @user.time_entries.build(project: alheio, started_at: Time.current)

    assert_not entry.valid?
    assert_includes entry.errors[:project], "não pertence a você"
  end

  test "task deve pertencer ao mesmo user via projeto" do
    outro = create_user(email: "outro@example.com")
    projeto_alheio = outro.projects.create!(name: "Alheio")
    task_alheia = projeto_alheio.tasks.create!(name: "Invasora", user: outro)

    entry = @user.time_entries.build(task: task_alheia, project: projeto_alheio, started_at: Time.current)

    assert_not entry.valid?
    assert_includes entry.errors[:task], "não pertence a você"
  end

  test "task exige project presente e do mesmo projeto" do
    project = @user.projects.create!(name: "Projeto")
    other_project = @user.projects.create!(name: "Outro")
    task = project.tasks.create!(name: "Design", user: @user)

    without_project = @user.time_entries.build(task: task, started_at: Time.current)
    assert_not without_project.valid?
    assert_includes without_project.errors[:task], "exige projeto"

    mismatched = @user.time_entries.build(project: other_project, task: task, started_at: Time.current)
    assert_not mismatched.valid?
    assert_includes mismatched.errors[:task], "não pertence ao projeto"
  end

  test "mudar ou limpar o projeto limpa a task no before_save" do
    first_project = @user.projects.create!(name: "Primeiro")
    second_project = @user.projects.create!(name: "Segundo")
    task = first_project.tasks.create!(name: "Design", user: @user)
    entry = @user.time_entries.create!(
      project: first_project,
      task: task,
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    entry.update!(project: second_project)
    assert_nil entry.reload.task_id

    entry.update!(project: nil)
    assert_nil entry.reload.task_id
  end

  test "default de billable segue a presença de rate no create e pode ser sobrescrito" do
    billed_project = @user.projects.create!(name: "Pago", rate_cents: 20000)
    free_project = @user.projects.create!(name: "Interno")

    billed = @user.time_entries.create!(
      project: billed_project,
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )
    free = @user.time_entries.create!(
      project: free_project,
      started_at: Time.current - 2.hours,
      ended_at: Time.current - 1.hour
    )
    forced = @user.time_entries.create!(
      project: free_project,
      billable: true,
      started_at: Time.current - 3.hours,
      ended_at: Time.current - 2.hours
    )

    assert billed.billable?
    assert_not free.billable?
    assert forced.billable?
  end

  test "billable_amount usa horas x rate com HALF_UP e só para entry finalizada billable" do
    project = @user.projects.create!(name: "Pago", rate_cents: 10000)
    started_at = Time.utc(2026, 7, 2, 12, 0, 0)

    finished = @user.time_entries.create!(
      project: project,
      started_at: started_at,
      ended_at: started_at + 20.minutes
    )
    non_billable = @user.time_entries.create!(
      project: project,
      billable: false,
      started_at: started_at,
      ended_at: started_at + 20.minutes
    )
    running = @user.time_entries.create!(project: project, started_at: started_at + 1.day)

    assert_equal 3333, finished.billable_amount.cents
    assert_equal "BRL", finished.billable_amount.currency.iso_code
    assert_nil non_billable.billable_amount
    assert_nil running.billable_amount
  end

  test "stop com duração zero deleta o entry" do
    entry = @user.time_entries.create!(started_at: Time.current)

    assert_difference -> { TimeEntry.count }, -1 do
      entry.stop_at(entry.started_at)
    end
  end

  test "índice único parcial barra dois timers rodando para o mesmo user" do
    @user.time_entries.create!(started_at: Time.current)

    assert_raises ActiveRecord::RecordNotUnique do
      duplicate = @user.time_entries.build(started_at: Time.current + 1.second)
      duplicate.save!(validate: false)
    end
  end

  test "users diferentes podem ter timers independentes" do
    other = create_user(email: "outro@example.com")

    assert_nothing_raised do
      @user.time_entries.create!(started_at: Time.current)
      other.time_entries.create!(started_at: Time.current)
    end
  end

  test "descrição não aparece em claro no SQL cru" do
    @user.time_entries.create!(
      description: "Segredo do timer",
      started_at: Time.current - 1.hour,
      ended_at: Time.current
    )

    raw = ActiveRecord::Base.connection.select_value("SELECT description FROM time_entries LIMIT 1")
    assert_not_nil raw
    assert_not_includes raw, "Segredo do timer"
  end
end
