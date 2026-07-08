source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Paginação Ruby puro para lists server-rendered (sem JS/build).
gem "pagy"

# Analytics interno (só admin): tracking de visitas/eventos via Ahoy + dashboard
# AhoyCaptain. Fork alextakitani/ahoy_captain portado pra SQLite (upstream é
# Postgres-only) — ver SQLITE_PORT.md no fork. Cobre landing pública + uso do app.
# github: (não path:) pra o build remoto do Kamal enxergar o fork no deploy.
gem "ahoy_matey"
gem "ahoy_captain", github: "alextakitani/ahoy_captain", branch: "main"

# Geocode das visitas (cidade/país no dashboard) via MaxMind GeoLite2 LOCAL —
# banco .mmdb offline, sem request externo nem custo (ideal pro homelab). O Ahoy
# geocoda via a gem geocoder; o lookup :geoip2 lê o .mmdb com a gem maxminddb.
# O arquivo mora em db/geoip/GeoLite2-City.mmdb (baixado à parte; ver docs/deploy.md).
gem "geocoder"
gem "maxminddb"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# CORS para a extensão de Chrome (origin chrome-extension://). Ver decisões §9.
gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

gem "action_policy", "~> 0.7.6"

# Dinheiro em Ruby puro (sem Node) — rate/amount viram objetos Money via `monetize`
# (Q11/Q20). Ver config/initializers/money.rb.
gem "money-rails", "~> 3.0"

# Superfície JSON de domínio (Q73): views .json.jbuilder declarativas, ESCALARES
# (rate_cents int + currency string, nunca Money cru — Q11). Mesmas rotas do HTML.
gem "jbuilder"

gem "caxlsx", "~> 4.5"

gem "csv", "~> 3.3"
