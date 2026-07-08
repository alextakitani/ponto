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

Ahoy.geocode = false # homelab sem serviço de geo
Ahoy.mask_ips = true  # privacidade básica (mascara o último octeto do IP)
# Mesma guarda do store: só resolve o user em controllers que expõem o método.
Ahoy.user_method = ->(controller) do
  controller.send(:current_ahoy_user) if controller.respond_to?(:current_ahoy_user, true)
end
