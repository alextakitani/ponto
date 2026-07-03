require "test_helper"

# Fatia 3.3 — DUPLICATE (Q47/Q13): re-disparar um entry finalizado. Copia
# descrição/projeto/task/billable pra INICIAR UM NOVO TIMER rodando AGORA (não copia
# horários). Ação sem verbo padrão vira resource (STYLE.md): POST
# /time_entries/:id/duplicate. Isolamento (Q23): duplicar entry alheio → 404.
class DuplicateTimeEntriesTest < ActionDispatch::IntegrationTest
  setup do
    @user = sign_in_as("duplicator@example.com")
    @user.update!(time_zone: "America/Sao_Paulo")
  end

  test "duplicar um entry finalizado inicia um timer novo com descrição/projeto/task copiados" do
    project = @user.projects.create!(name: "Projeto dup")
    task = project.tasks.create!(name: "Design", user: @user)
    finished = @user.time_entries.create!(
      project: project,
      task: task,
      description: "Trabalho de ontem",
      started_at: Time.utc(2026, 7, 1, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 10, 0, 0)
    )

    assert_difference -> { @user.time_entries.count }, +1 do
      post time_entry_duplicate_path(finished), headers: turbo_headers("timer_bar")
    end

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.body, %(target="timer_bar")

    running = @user.time_entries.find_by!(ended_at: nil)
    assert_not_equal finished.id, running.id
    assert_equal "Trabalho de ontem", running.description
    assert_equal project.id, running.project_id
    assert_equal task.id, running.task_id
    assert_nil running.ended_at
    # Novo timer começa AGORA, não copia horários do original.
    assert_not_equal finished.started_at, running.started_at
  end

  test "duplicar com um timer já rodando devolve 409 sem criar entry" do
    project = @user.projects.create!(name: "Projeto dup")
    finished = @user.time_entries.create!(
      project: project,
      description: "Antigo",
      started_at: Time.utc(2026, 7, 1, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 10, 0, 0)
    )
    running = @user.time_entries.create!(description: "Já rodando", started_at: Time.current - 5.minutes)

    assert_no_difference -> { @user.time_entries.count } do
      post time_entry_duplicate_path(finished), headers: turbo_headers("timer_bar")
    end

    assert_response :conflict
    assert_includes response.body, "Já rodando"
    assert_equal running.id, @user.time_entries.find_by!(ended_at: nil).id
  end

  test "duplicar entry de outro user dá 404 (isolamento Q23)" do
    other = create_user(email: "outro-dup@example.com")
    alheio = other.time_entries.create!(
      description: "Privado",
      started_at: Time.utc(2026, 7, 1, 9, 0, 0),
      ended_at: Time.utc(2026, 7, 1, 10, 0, 0)
    )

    assert_no_difference -> { TimeEntry.count } do
      post time_entry_duplicate_path(alheio), headers: turbo_headers("timer_bar")
    end

    assert_response :not_found
  end

  private
    def turbo_headers(frame_id)
      {
        "Turbo-Frame" => frame_id,
        "Accept" => "text/vnd.turbo-stream.html, text/html"
      }
    end
end
