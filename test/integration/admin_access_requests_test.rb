require "test_helper"

# Fluxo de controle da fila de pedidos no painel (Q35/Q68). A lógica de domínio
# (approve!/reject!) já é testada em access_request_approval_test; aqui checamos o
# WIRING do controller: aprovar cria conta + dispara convite, rejeitar é silencioso,
# e a resposta Turbo Stream remove a linha inline da fila.
class AdminAccessRequestsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    sign_in_as("chefe@example.com", admin: true)
  end

  test "aprovar cria a conta, dispara o convite e some da fila via Turbo Stream" do
    request = AccessRequest.create!(email: "pede@example.com", name: "Pede")

    assert_difference -> { User.count }, +1 do
      perform_enqueued_jobs do
        post admin_access_request_approval_path(request), as: :turbo_stream
      end
    end

    assert request.reload.approved?
    assert_equal [ "pede@example.com" ], ActionMailer::Base.deliveries.last.to
    # Turbo Stream remove a linha do DOM (id do dom_id do request).
    assert_match "turbo-stream", response.media_type
    assert_match %r{action="remove"[^>]*target="#{ActionView::RecordIdentifier.dom_id(request)}"}, response.body
  end

  test "rejeitar marca rejected, NÃO manda e-mail e some da fila via Turbo Stream" do
    request = AccessRequest.create!(email: "nao@example.com")

    assert_no_emails do
      perform_enqueued_jobs do
        post admin_access_request_rejection_path(request), as: :turbo_stream
      end
    end

    assert request.reload.rejected?
    assert_match %r{action="remove"[^>]*target="#{ActionView::RecordIdentifier.dom_id(request)}"}, response.body
  end

  test "aprovar sem Turbo (HTML) redireciona pro painel" do
    request = AccessRequest.create!(email: "html@example.com")

    perform_enqueued_jobs { post admin_access_request_approval_path(request) }
    assert_redirected_to admin_root_path
  end
end
