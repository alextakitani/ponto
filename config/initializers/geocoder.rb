# Geocode LOCAL via MaxMind GeoLite2 (.mmdb offline) — sem request externo, sem
# custo. O Ahoy chama Geocoder.search(ip) num job; aqui dizemos ao geocoder pra
# resolver contra o arquivo local em vez de uma API HTTP.
#
# O arquivo NÃO é versionado (grande + licença própria). Procuramos em, na ordem:
#   1. ENV["GEOIP_CITY_DB"] (override explícito)
#   2. storage/geoip/GeoLite2-City.mmdb  -> PRODUÇÃO: cai no volume ponto_storage
#      (o mesmo do SQLite), então entra no vzdump do Proxmox de graça.
#   3. db/geoip/GeoLite2-City.mmdb       -> DEV local.
# Ver docs/deploy.md. Sem arquivo, Ahoy.geocode fica false (ver ahoy.rb) e nada quebra.
GEOIP_CITY_DB = [
  ENV["GEOIP_CITY_DB"],
  Rails.root.join("storage", "geoip", "GeoLite2-City.mmdb").to_s,
  Rails.root.join("db", "geoip", "GeoLite2-City.mmdb").to_s
].compact.find { |path| File.exist?(path) }

if GEOIP_CITY_DB
  Geocoder.configure(ip_lookup: :geoip2, geoip2: { file: GEOIP_CITY_DB })
elsif defined?(Rails.logger)
  Rails.logger.info("[geocoder] GeoLite2-City.mmdb ausente — geocode local desativado até baixar o .mmdb (ver docs/deploy.md)")
end
