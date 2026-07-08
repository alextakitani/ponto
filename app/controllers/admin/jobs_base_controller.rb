module Admin
  # Controller base do dashboard de jobs (Mission Control). A engine é apontada
  # pra cá via MissionControl::Jobs.base_controller_class (initializer).
  #
  # Por que um controller SÓ pra isto, e não o ApplicationController normal: a
  # engine roda dentro deste base, e a concern Authentication do app redireciona
  # pro sign_in_path usando os HELPERS da engine (que injetam server_id) — o que
  # estoura "No route matches ... server_id". Aqui herdamos de ActionController::
  # Base (como o AhoyCaptain) e resolvemos a MESMA sessão assinada do app à mão,
  # exigindo admin. Anônimo -> login; logado não-admin -> 404 (não vaza).
  class JobsBaseController < ActionController::Base
    before_action :require_jobs_admin

    private
      def require_jobs_admin
        session = Session.find_signed(cookies.signed[:session_token])
        Current.session = session if session # resolve Current.user em cascata

        return if session&.user&.admin?

        if session&.user
          raise ActionController::RoutingError, "Not Found"
        else
          redirect_to main_app.sign_in_path
        end
      end
  end
end
