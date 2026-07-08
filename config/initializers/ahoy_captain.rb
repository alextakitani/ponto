# Dashboard de analytics (AhoyCaptain) — montado em /admin/analytics (só admin).
# O fork já detecta o adapter (SQLite aqui) e gera a sintaxe SQL certa via
# AhoyCaptain::SQLDialect; url_column/url_exists saem corretos por padrão, não
# precisamos sobrescrever. Ver ~/Projetos/ahoy_captain/SQLITE_PORT.md.
AhoyCaptain.configure do |config|
  config.models.visit = "::Ahoy::Visit"
  config.models.event = "::Ahoy::Event"
  config.event.view_name = "$view"
end
