ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Roda os testes em paralelo no número de cores da máquina.
    parallelize(workers: :number_of_processors)

    # Sem fixtures: criamos só os dados que cada teste precisa (single-user, models
    # enxutos). Use os helpers abaixo para reduzir ruído.
    def create_user(email: "user@example.com")
      User.create!(email: email)
    end
  end
end
