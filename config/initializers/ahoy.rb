class Ahoy::Store < Ahoy::DatabaseStore
  # Ponto usa Current.user (não current_user do Devise). O user vem do
  # ApplicationController via current_ahoy_user — mas controllers internos do
  # Rails (ex.: Rails::PwaController, que serve /manifest.json e o service worker)
  # NÃO herdam do nosso ApplicationController e não têm esse método. Guardamos
  # com respond_to? pra não estourar NoMethodError nesses controllers.
  def authenticate(data)
    data[:user] = ahoy_user
    super
  end

  private
    def ahoy_user
      controller.respond_to?(:current_ahoy_user, true) ? controller.send(:current_ahoy_user) : nil
    end
end

# Geocode das visitas (cidade/país no dashboard) só quando o .mmdb local existir
# — senão o job cairia no backend HTTP default do geocoder (não queremos). Ver
# config/initializers/geocoder.rb e docs/deploy.md. Mesma busca de path que o
# geocoder.rb faz (ENV -> storage/geoip -> db/geoip); repetida aqui porque este
# initializer carrega ANTES do geocoder.rb (ordem alfabética) e a constante dele
# ainda não existe.
Ahoy.geocode = [
  ENV["GEOIP_CITY_DB"],
  Rails.root.join("storage", "geoip", "GeoLite2-City.mmdb").to_s,
  Rails.root.join("db", "geoip", "GeoLite2-City.mmdb").to_s
].compact.any? { |path| File.exist?(path) }
# mask_ips DESLIGADO (decisão do dono): geo a nível de cidade exige o IP inteiro.
# Trade-off privacidade↔precisão consciente; o dado fica só no dashboard do admin.
Ahoy.mask_ips = false
# Mesma guarda do store: só resolve o user em controllers que expõem o método.
Ahoy.user_method = ->(controller) do
  controller.send(:current_ahoy_user) if controller.respond_to?(:current_ahoy_user, true)
end
