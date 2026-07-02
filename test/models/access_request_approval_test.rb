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

  # --- atomicidade do approve! (Fix code review) ------------------------------
  # Se a criação do User falha, a transação faz rollback: o request CONTINUA
  # pending E nenhum convite é enfileirado. O enqueue do mailer mora FORA da
  # transação (job em banco separado + sem enqueue_after_transaction_commit), mas
  # só dispara se a transação commitou — logo, um create! que estoura não pode
  # deixar e-mail órfão.
  test "approve! faz rollback se User.create! falha: request segue pending e sem e-mail" do
    request = AccessRequest.create!(email: "falha@example.com", name: "Falha")

    with_failing_user_create do
      assert_no_difference -> { User.count } do
        assert_no_enqueued_jobs do
          assert_raises(ActiveRecord::RecordInvalid) { request.approve! }
        end
      end
    end

    assert request.reload.pending?, "o request deve continuar pending após o rollback"
    assert_empty ActionMailer::Base.deliveries
  end

  private
    # Minitest 6 não traz mais o `stub`; substituímos User.create! por um que
    # estoura (RecordInvalid) e restauramos no ensure. Cada worker paralelo é um
    # processo próprio, então mexer no singleton method aqui não vaza pros outros.
    def with_failing_user_create
      original = User.method(:create!)
      User.define_singleton_method(:create!) { |*| raise ActiveRecord::RecordInvalid.new(User.new) }
      yield
    ensure
      User.singleton_class.send(:remove_method, :create!)
      User.define_singleton_method(:create!, original)
    end
end
