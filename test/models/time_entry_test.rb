require "test_helper"

# Lógica NOSSA do TimeEntry (Fatia 3.1): invariantes de tempo, snapshot de rate,
# integridade task↔project, default de billable, cálculo faturável, descarte de
# duração-zero e isolamento por user. Não testamos belongs_to/monetize/dependent
# (framework/gem).
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
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 0, 0)
    )
    free = @user.time_entries.create!(
      project: free_project,
      started_at: Time.utc(2026, 7, 2, 10, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )
    forced = @user.time_entries.create!(
      project: free_project,
      billable: true,
      started_at: Time.utc(2026, 7, 2, 11, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 12, 0, 0)
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
      started_at: started_at + 20.minutes,
      ended_at: started_at + 40.minutes
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

  test "validação de overlap bloqueia update manual que criaria sobreposição" do
    @user.update!(time_zone: "America/Sao_Paulo")
    first = @user.time_entries.create!(
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 0, 0)
    )
    second = @user.time_entries.create!(
      started_at: first.ended_at,
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )

    second.started_at = Time.utc(2026, 7, 2, 9, 30, 0)

    assert_not second.valid?
    assert second.errors[:started_at].any?
    assert_includes second.errors[:started_at].join, "06:00 - 07:00"
  end

  test "entradas tocando na borda não são overlap" do
    first = @user.time_entries.create!(
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 0, 0)
    )
    touching = @user.time_entries.build(
      started_at: first.ended_at,
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )

    assert touching.valid?, touching.errors.full_messages.to_sentence
  end

  test "editar só descrição em entry já sobreposto não bloqueia" do
    @user.time_entries.create!(
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 0, 0)
    )
    overlapping = @user.time_entries.build(
      started_at: Time.utc(2026, 7, 2, 9, 30, 0),
      ended_at: Time.utc(2026, 7, 2, 10, 30, 0)
    )
    overlapping.allow_overlap = true
    overlapping.save!

    overlapping.reload.description = "Ajuste sem mexer em horário"

    assert overlapping.valid?, overlapping.errors.full_messages.to_sentence
  end

  test "stop_at de timer rodando que sobreporia continua funcionando" do
    @user.time_entries.create!(
      started_at: Time.utc(2026, 7, 2, 10, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )
    running = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 9, 30, 0))

    running.stop_at(Time.utc(2026, 7, 2, 10, 30, 0))

    assert_equal Time.utc(2026, 7, 2, 10, 30, 0), running.reload.ended_at
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

  # --- Split (Q48): quebra um entry finalizado em dois no ponto de corte. ---

  test "split_at no meio encurta A e cria B como cópia fiel (descrição/projeto/task/billable)" do
    project = @user.projects.create!(name: "Split", rate_cents: 12000)
    task = project.tasks.create!(name: "Design", user: @user)
    started_at = Time.utc(2026, 7, 2, 9, 0, 0)
    ended_at = Time.utc(2026, 7, 2, 11, 0, 0)
    entry = @user.time_entries.create!(
      project: project,
      task: task,
      description: "Trabalho longo",
      billable: true,
      started_at: started_at,
      ended_at: ended_at
    )
    cut = Time.utc(2026, 7, 2, 10, 0, 0)

    second = entry.split_at(cut)

    entry.reload
    assert_equal started_at, entry.started_at
    assert_equal cut, entry.ended_at

    assert_equal cut, second.started_at
    assert_equal ended_at, second.ended_at
    assert_equal "Trabalho longo", second.description
    assert_equal project.id, second.project_id
    assert_equal task.id, second.task_id
    assert_equal true, second.billable
    assert_equal @user.id, second.user_id
  end

  test "split re-resolve o snapshot de cada metade (B vem do project.effective_rate, não copia A)" do
    client = @user.clients.create!(name: "Acme", currency: "USD", rate_cents: 10000)
    project = @user.projects.create!(name: "Site", client: client)
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 11, 0, 0)
    )
    assert_equal 10000, entry.rate_cents

    # Reajuste ENTRE o create de A e o split: A congelou 10000; B, como record novo,
    # re-resolve do project (agora 25000). Prova que B NÃO copia rate_cents de A cru.
    client.update!(rate_cents: 25000)

    second = entry.split_at(Time.utc(2026, 7, 2, 10, 0, 0))

    assert_equal 10000, entry.reload.rate_cents, "A permanece congelada (Q10)"
    assert_equal 25000, second.rate_cents, "B re-resolve do project.effective_rate"
    assert_equal "USD", second.currency
  end

  test "split preserva a duração total: A + B somam a duração original" do
    project = @user.projects.create!(name: "Split")
    started_at = Time.utc(2026, 7, 2, 9, 0, 0)
    ended_at = Time.utc(2026, 7, 2, 11, 0, 0)
    entry = @user.time_entries.create!(project: project, started_at: started_at, ended_at: ended_at)
    original_duration = entry.duration_seconds

    second = entry.split_at(Time.utc(2026, 7, 2, 9, 37, 13))

    assert_equal original_duration, entry.reload.duration_seconds + second.duration_seconds
  end

  test "split fora do intervalo (bordas ou além) levanta erro e não cria nada" do
    project = @user.projects.create!(name: "Split")
    started_at = Time.utc(2026, 7, 2, 9, 0, 0)
    ended_at = Time.utc(2026, 7, 2, 11, 0, 0)
    entry = @user.time_entries.create!(project: project, started_at: started_at, ended_at: ended_at)

    [ started_at, ended_at, started_at - 1.minute, ended_at + 1.minute ].each do |bad_cut|
      assert_no_difference -> { TimeEntry.count } do
        assert_raises(ArgumentError) { entry.split_at(bad_cut) }
      end
      # A intacta: o rollback preserva o ended_at original mesmo se o update rodou.
      assert_equal ended_at, entry.reload.ended_at
    end
  end

  test "split de entry RODANDO levanta erro (só finalizado divide)" do
    running = @user.time_entries.create!(started_at: Time.utc(2026, 7, 2, 9, 0, 0))

    err = assert_raises(ArgumentError) do
      running.split_at(Time.utc(2026, 7, 2, 9, 30, 0))
    end
    # Afere a MENSAGEM (não só a classe): sem a guarda explícita, o cut < nil
    # levantaria "comparison of Time with nil failed" — mesma classe, mensagem
    # críptica que vazaria pro usuário (o controller repassa e.message).
    assert_equal "só é possível dividir entradas finalizadas", err.message
    assert_nil running.reload.ended_at
  end

  test "split é ATÔMICO: se B falha ao salvar, A faz rollback pro ended_at original" do
    project = @user.projects.create!(name: "Atômico")
    original_ended_at = Time.utc(2026, 7, 2, 11, 0, 0)
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.utc(2026, 7, 2, 9, 0, 0),
      ended_at: original_ended_at
    )
    cut = Time.utc(2026, 7, 2, 10, 0, 0)
    count_before = TimeEntry.count

    # Faz a metade B (nasce no corte) falhar ao salvar, DEPOIS de A ser encurtado
    # dentro do split_at. Sem a transação, A ficaria corrompido e B some (perda de
    # dados); com a transação, tudo faz rollback. O método é definido/removido no
    # ensure pra não vazar entre testes.
    TimeEntry.define_method(:__probe_fail_split_b) do
      errors.add(:base, "probe") if new_record? && started_at == Time.utc(2026, 7, 2, 10, 0, 0)
    end
    TimeEntry.set_callback(:validate, :before, :__probe_fail_split_b)
    begin
      assert_raises(ActiveRecord::RecordInvalid) { entry.split_at(cut) }
    ensure
      TimeEntry.skip_callback(:validate, :before, :__probe_fail_split_b)
      TimeEntry.remove_method(:__probe_fail_split_b)
    end

    assert_equal original_ended_at, entry.reload.ended_at, "A deveria ter feito rollback"
    assert_equal count_before, TimeEntry.count
  end

  test "split cruza a meia-noite: cada metade cai no dia do seu started_at" do
    project = @user.projects.create!(name: "Vira o dia")
    entry = @user.time_entries.create!(
      project: project,
      started_at: Time.utc(2026, 7, 1, 23, 0, 0),
      ended_at: Time.utc(2026, 7, 2, 1, 0, 0)
    )

    second = entry.split_at(Time.utc(2026, 7, 2, 0, 0, 0))

    assert_equal Date.new(2026, 7, 1), entry.reload.started_at.utc.to_date
    assert_equal Date.new(2026, 7, 2), second.started_at.utc.to_date
  end
end
