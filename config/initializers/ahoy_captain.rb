# Dashboard de analytics (AhoyCaptain) — montado em /admin/analytics (só admin).
# O fork já detecta o adapter (SQLite aqui) e gera a sintaxe SQL certa via
# AhoyCaptain::SQLDialect; url_column/url_exists saem corretos por padrão.
# Ver ~/Projetos/ahoy_captain/SQLITE_PORT.md.
AhoyCaptain.configure do |config|
  config.models.visit = "::Ahoy::Visit"
  config.models.event = "::Ahoy::Event"
  config.event.view_name = "$view"
end

# Autorização do dashboard (só admin). A engine tem ApplicationController próprio
# (herda de ActionController::Base, NÃO do nosso), então injetamos um gate aqui.
# Feito via to_prepare pra sobreviver aos reloads de dev.
#
# NÃO reusamos a concern Authentication inteira: o request_authentication dela
# chama sign_in_path sem prefixo, que não resolve dentro da engine (helpers da
# engine != do app). E NÃO usamos constraint de rota: req.cookie_jar não tem key
# generator num constraint ("undefined method 'generate_key' for nil"). Em vez
# disso resolvemos a MESMA sessão assinada do app (Session.find_signed) e, na
# falha, redirecionamos via main_app.
Rails.application.config.to_prepare do
  AhoyCaptain::ApplicationController.class_eval do
    before_action :require_analytics_admin

    private
      def require_analytics_admin
        session = Session.find_signed(cookies.signed[:session_token])
        Current.session = session if session # resolve Current.user em cascata

        return if session&.user&.admin?

        if session&.user
          # logado não-admin: 404 (não vaza que a página existe)
          raise ActionController::RoutingError, "Not Found"
        else
          redirect_to main_app.sign_in_path
        end
      end
  end
end
