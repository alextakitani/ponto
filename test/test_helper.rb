ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Roda os testes em paralelo no número de cores da máquina.
    parallelize(workers: :number_of_processors)

    # Sem fixtures: criamos só os dados que cada teste precisa (single-user, models
    # enxutos). Use os helpers abaixo para reduzir ruído.
    def create_user(email: "user@example.com", onboarded_at: Time.current, **attributes)
      User.create!(email: email, onboarded_at: onboarded_at, **attributes)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # `perform_enqueued_jobs` (mailer roda via deliver_later — ver CLAUDE.md).
    include ActiveJob::TestHelper

    # Estabelece a sessão de cookie pelo fluxo REAL de login (dois passos: pede o
    # código, lê o dígito do e-mail enviado, troca pelo código). Antes vivia copiado
    # em 9 integration tests; consolidado aqui. Opções cobrindo as variantes:
    #   admin:            cria o user já admin (default false).
    #   user:             usa um user pré-existente em vez de criar (login-only não
    #                     recria; o email do param só dispara o código).
    #   keep_active_admin: garante que exista OUTRO admin ativo antes do login —
    #                     alguns testes exercitam a suspensão (invariante Q34c: só
    #                     suspende/rebaixa havendo admin ativo restante).
    # Retorna o user. Limpa as deliveries no fim para que asserts posteriores
    # (convite/aprovação) leiam o PRÓXIMO e-mail, não o código de login.
    def sign_in_as(email, admin: false, user: nil, keep_active_admin: false)
      user ||= User.find_or_create_by!(email: email) do |u|
        u.admin = admin
        u.onboarded_at = Time.current
      end
      ensure_active_admin if keep_active_admin

      perform_enqueued_jobs { post sign_in_path, params: { email: email } }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]
      post sign_in_session_path, params: { code: code }
      ActionMailer::Base.deliveries.clear

      user
    end

    private
      # Um admin ativo "de fundo" pra satisfazer a invariante que exige admin ativo
      # restante ao suspender/rebaixar (Q34c). Só cria se ainda não houver nenhum.
      def ensure_active_admin
        return if User.exists?(admin: true)

        User.create!(email: "background-admin@example.com", admin: true, onboarded_at: Time.current)
      end
  end
end
