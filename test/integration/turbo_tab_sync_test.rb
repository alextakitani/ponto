require "test_helper"
require "turbo/broadcastable/test_helper"

# Garante que mutações em timer/entries disparam broadcast de refresh no stream do
# user correto (Q23: isolamento total por user). O que testamos é NOSSO — a
# configuração `broadcasts_refreshes_to :user` nos models, não o roteamento genérico
# do turbo-rails:
#
#   1. Salvar um TimeEntry/Task de fato dispara o refresh no stream do user DONO
#      (exercita a callback real, não um broadcast manual equivalente).
#   2. Esse broadcast NUNCA chega no stream de OUTRO user (a garantia do Q23).
#
# `broadcasts_refreshes_to` usa `broadcast_refresh_later_to`, que enfileira um job com
# debounce. Rodamos os jobs inline com `perform_enqueued_jobs` (mesmo padrão do mailer,
# ver test_helper) para a callback produzir o broadcast síncrono que a asserção captura.
class TurboTabSyncTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  setup do
    @user  = create_user(email: "sync@example.com")
    @other = create_user(email: "other@example.com")
  end

  # ── A callback do TimeEntry dispara refresh no stream do próprio user ──

  test "salvar um TimeEntry emite refresh no stream do user dono" do
    assert_turbo_stream_broadcasts @user do
      perform_enqueued_jobs { create_entry(@user) }
    end
  end

  # ── E NUNCA no stream de outro user (a garantia do Q23) ──

  test "TimeEntry de @user NÃO emite refresh no stream de @other" do
    assert_no_turbo_stream_broadcasts @other do
      perform_enqueued_jobs { create_entry(@user) }
    end
  end

  # ── A callback do Task também é escopada por user (cenário da task deletada) ──

  test "salvar uma Task emite refresh no stream do dono, não no de @other" do
    project = @user.projects.create!(name: "Sync", color: "#3b82f6")

    assert_turbo_stream_broadcasts @user do
      assert_no_turbo_stream_broadcasts @other do
        perform_enqueued_jobs do
          @user.tasks.create!(name: "sub-bucket", project: project)
        end
      end
    end
  end

  # ── Sanity check barato: o stream name é o GID do user, único por conta ──

  test "stream name de @user e @other são diferentes" do
    assert_not_equal @user.to_gid_param, @other.to_gid_param,
      "Cada user tem GID único — streams distintos garantem o isolamento Q23"
  end

  private
    def create_entry(user)
      user.time_entries.create!(started_at: Time.current, ended_at: 1.hour.from_now)
    end
end
