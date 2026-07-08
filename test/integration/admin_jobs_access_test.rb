require "test_helper"

# Auth do dashboard de jobs (Mission Control montado em /admin/jobs). Engine de
# terceiro com controller próprio: o HTTP Basic embutido fica DESLIGADO e o gate
# "só admin" é injetado no MissionControl::Jobs::ApplicationController
# (config/initializers/mission_control_jobs.rb), mesmo padrão do AhoyCaptain.
#
# Jobs é dado OPERACIONAL do admin — ninguém além do admin toca o dashboard.
class AdminJobsAccessTest < ActionDispatch::IntegrationTest
  test "anônimo não acessa o dashboard de jobs" do
    get "/admin/jobs"
    assert_not_equal 200, response.status
  end

  test "user comum autenticado não acessa o dashboard de jobs" do
    sign_in_as("membro@example.com", keep_active_admin: true) # não-admin
    get "/admin/jobs"
    assert_not_equal 200, response.status
  end

  # O admin PASSA pela autorização (não é redirecionado pro login nem recebe
  # 404). Não afirmamos 200 aqui: o Mission Control chama `.activating` no queue
  # adapter, que o TestAdapter (ambiente de teste) não tem — o dashboard só roda
  # de fato com o Solid Queue ativo (dev/prod). O que este teste garante é que o
  # gate de admin deixa o admin ENTRAR; a validação visual real é no browser.
  test "admin não é barrado pelo gate de jobs" do
    sign_in_as("chefe@example.com", admin: true, keep_active_admin: true)

    error = assert_raises(NoMethodError) { get "/admin/jobs" }
    assert_match "activating", error.message # chegou no Mission Control, não no gate
  end
end
