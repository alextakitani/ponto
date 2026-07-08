module Admin
  # Uso da API (CLI/extensão via Bearer). O AhoyCaptain não mostra estes acessos
  # porque ancora tudo num JOIN com ahoy_visits e os `api_request` não têm visita
  # (ver ApplicationController#track_api_request e a rota). Esta página os lê
  # direto de Ahoy::Event: um resumo por endpoint + a timeline dos últimos.
  #
  # Admin é operacional e cego pro domínio (Q25b): aqui só olhamos metadados de
  # acesso (endpoint, método, quando), NUNCA o conteúdo das entries.
  class ApiUsageController < BaseController
    def show
      @usage_by_endpoint = Ahoy::Event.api_usage_by_endpoint
      @total_requests = Ahoy::Event.api_requests.count
      @pagy, @recent_requests = pagy(
        Ahoy::Event.api_requests.includes(:user).order(time: :desc),
        limit: 50
      )
    end
  end
end
