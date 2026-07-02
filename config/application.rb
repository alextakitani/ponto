require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Ponto
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # DB em UTC (default do Rails). App opera em horário de SP. Ver decisões §8.
    config.time_zone = "America/Sao_Paulo"
    # config.eager_load_paths << Rails.root.join("extras")

    # i18n (Q79) — a LANDING é bilíngue pt-BR/en; o resto do app é pt-BR
    # hardcoded (fora de escopo). Default pt-BR. Fallback SÓ para :"pt-BR" (a
    # copy canônica): assim uma chave faltante degrada pro PT sem quebrar. Isso
    # NÃO nos autoriza a deixar buracos na copy EN — garantimos cobertura total
    # das chaves em en.yml (o teste checa que a página EN não vaza strings PT).
    config.i18n.available_locales = [ :"pt-BR", :en ]
    config.i18n.default_locale = :"pt-BR"
    config.i18n.fallbacks = [ :"pt-BR" ]

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
