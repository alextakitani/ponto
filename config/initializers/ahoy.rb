class Ahoy::Store < Ahoy::DatabaseStore
  # Ponto usa Current.user (não current_user do Devise).
  # Sobrescrevemos authenticate para integrar com o padrão do app.
  def authenticate(data)
    data[:user] = controller.send(:current_ahoy_user)
    super
  end
end

Ahoy.geocode = false # homelab sem serviço de geo
Ahoy.mask_ips = true # privacidade básica
Ahoy.user_method = ->(controller) { controller.send(:current_ahoy_user) }
