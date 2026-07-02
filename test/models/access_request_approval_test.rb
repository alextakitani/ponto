require "test_helper"

# Lógica nossa (Q35): resolução de um AccessRequest pending pelo admin.
#   approve! -> cria o User (transação), marca approved e dispara o convite Pull
#               (InvitationMailer.created). Se o e-mail JÁ virou conta (convite
#               manual entre o pedido e a aprovação), só marca approved — sem criar
#               nem mandar e-mail.
#   reject!  -> marca rejected, SILENCIOSO (nenhum e-mail).
# Só faz sentido a partir de pending; approve!/reject! de um request já resolvido
# levanta erro (transição inválida).
class AccessRequestApprovalTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { ActionMailer::Base.deliveries.clear }

  # --- approve! feliz ---------------------------------------------------------

  test "approve! cria o User com email/name, marca approved e dispara o convite" do
    request = AccessRequest.create!(email: "novo@example.com", name: "Novo")

    assert_difference -> { User.count }, +1 do
      perform_enqueued_jobs { request.approve! }
    end

    user = User.find_by(email: "novo@example.com")
    assert_equal "Novo", user.name
    assert request.reload.approved?

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "novo@example.com" ], mail.to
  end

  # --- approve! com user já existente (convite manual no meio) -----------------

  test "approve! quando o e-mail JÁ é conta só marca approved (sem criar nem enviar)" do
    create_user(email: "existe@example.com")
    request = AccessRequest.create!(email: "existe@example.com", name: "Ignorado")

    assert_no_difference -> { User.count } do
      perform_enqueued_jobs { request.approve! }
    end

    assert request.reload.approved?
    assert_empty ActionMailer::Base.deliveries
  end

  # --- reject! silencioso ------------------------------------------------------

  test "reject! marca rejected e NÃO dispara e-mail nenhum" do
    request = AccessRequest.create!(email: "recusado@example.com")

    assert_no_difference -> { User.count } do
      perform_enqueued_jobs { request.reject! }
    end

    assert request.reload.rejected?
    assert_empty ActionMailer::Base.deliveries
  end

  # --- transições inválidas ----------------------------------------------------

  test "approve! de um request já resolvido levanta erro (não reprocessa)" do
    request = AccessRequest.create!(email: "ja@example.com")
    request.reject!

    assert_raises(AccessRequest::InvalidTransition) { request.approve! }
    assert_equal 0, User.where(email: "ja@example.com").count
  end

  test "reject! de um request já resolvido levanta erro" do
    request = AccessRequest.create!(email: "ja@example.com")
    perform_enqueued_jobs { request.approve! }
    ActionMailer::Base.deliveries.clear

    assert_raises(AccessRequest::InvalidTransition) { request.reject! }
    assert_empty ActionMailer::Base.deliveries
  end
end
