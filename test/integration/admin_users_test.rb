require "test_helper"

# Fluxo de controle das ações de admin sobre CONTAS (Q29/Q31/Q33/Q34). Testamos a
# lógica NOSSA (proteções da deleção, gate do reenviar, reembrulho dos erros de
# invariante), não o CRUD do framework.
class AdminUsersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    @admin = sign_in_as("chefe@example.com", admin: true)
  end

  # --- Convidar (Q29) ---------------------------------------------------------

  test "convidar cria a conta e dispara o convite" do
    assert_difference -> { User.count }, +1 do
      perform_enqueued_jobs do
        post admin_users_path, params: { user: { email: "novo@example.com", name: "Novo" } }
      end
    end

    user = User.find_by(email: "novo@example.com")
    assert_equal "Novo", user.name
    assert_equal [ "novo@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "convidar e-mail já existente NÃO cria conta e mostra erro amigável" do
    create_user(email: "existe@example.com")

    assert_no_difference -> { User.count } do
      post admin_users_path, params: { user: { email: "existe@example.com" } }
    end
    follow_redirect!
    assert_match(/já (está|foi) (em uso|utilizado)|já existe|taken|em uso/i, response.body)
  end

  # --- Reenviar convite (Q31) -------------------------------------------------

  test "reenviar convite re-dispara o e-mail pra quem nunca entrou" do
    convidado = create_user(email: "convidado@example.com")

    assert_emails 1 do
      perform_enqueued_jobs { post admin_user_invitation_path(convidado) }
    end
    assert_equal [ "convidado@example.com" ], ActionMailer::Base.deliveries.last.to
  end

  test "reenviar convite pra quem já entrou é no-op com aviso (sem e-mail)" do
    ativo = create_user(email: "ativo@example.com")
    ativo.sessions.create!

    assert_no_emails do
      perform_enqueued_jobs { post admin_user_invitation_path(ativo) }
    end
  end

  # --- Suspender / Reativar (Q34) ---------------------------------------------

  test "suspender e reativar uma conta" do
    membro = create_user(email: "membro@example.com")

    post admin_user_suspension_path(membro)
    assert membro.reload.suspended?

    delete admin_user_suspension_path(membro)
    assert_not membro.reload.suspended?
  end

  test "suspender o último admin ativo é barrado com alert (invariante Q34c)" do
    # @admin é o único admin ativo; suspendê-lo violaria a invariante.
    post admin_user_suspension_path(@admin)
    assert_not @admin.reload.suspended?
    follow_redirect!
    assert_match(/último admin/i, response.body)
  end

  # --- Promover / Rebaixar (Q34) ----------------------------------------------

  test "promover e rebaixar admin" do
    outro = create_user(email: "outro@example.com")

    post admin_user_admin_role_path(outro)
    assert outro.reload.admin?

    delete admin_user_admin_role_path(outro)
    assert_not outro.reload.admin?
  end

  test "rebaixar o último admin ativo é barrado com alert" do
    delete admin_user_admin_role_path(@admin)
    assert @admin.reload.admin?
    follow_redirect!
    assert_match(/último admin/i, response.body)
  end

  # --- Deletar (Q33): proteções -----------------------------------------------

  test "deletar com confirmação certa apaga a bolha inteira" do
    outro_admin = create_user(email: "co-admin@example.com") # mantém ≥1 admin ativo
    outro_admin.update!(admin: true)
    alvo = create_user(email: "alvo@example.com")
    alvo.sessions.create!
    alvo.access_tokens.create!(permission: "read")

    assert_difference -> { User.count }, -1 do
      delete admin_user_path(alvo), params: { email_confirmation: "alvo@example.com" }
    end
    assert_not User.exists?(alvo.id)
    assert_equal 0, Session.where(user_id: alvo.id).count
  end

  test "deletar com confirmação errada RECUSA (não apaga) e avisa" do
    alvo = create_user(email: "alvo@example.com")

    assert_no_difference -> { User.count } do
      delete admin_user_path(alvo), params: { email_confirmation: "errado@example.com" }
    end
    assert User.exists?(alvo.id)
    follow_redirect!
    assert_match(/confirmação não confere/i, response.body)
  end

  test "não pode deletar A SI MESMO (barrado pela policy, 403)" do
    assert_no_difference -> { User.count } do
      delete admin_user_path(@admin), params: { email_confirmation: @admin.email }
    end
    assert_response :forbidden
    assert User.exists?(@admin.id)
  end

  test "deletar o último admin ativo é barrado pelo model (via controller)" do
    # @admin é o único admin; outro admin faz a ação pra escapar da trava
    # de auto-deleção e exercitar a invariante do model.
    operador = create_user(email: "op@example.com")
    operador.update!(admin: true)
    sign_in_as("op@example.com", user: operador)
    operador.update!(admin: false) # agora @admin volta a ser o único admin ativo

    assert_no_difference -> { User.count } do
      delete admin_user_path(@admin), params: { email_confirmation: @admin.email }
    end
    assert User.exists?(@admin.id)
  end

  private
    def sign_in_as(email, admin: false, user: nil)
      user ||= User.create!(email: email, admin: admin)
      perform_enqueued_jobs { post sign_in_path, params: { email: email } }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post sign_in_session_path, params: { code: code }
      ActionMailer::Base.deliveries.clear
      user
    end
end
