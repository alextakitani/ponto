# Pedido de acesso público (Q24): grava um AccessRequest e SEMPRE responde
# genérico (anti-enumeração — não revela se o e-mail já é conta/pedido). O admin
# aprova/recusa depois (Task 1.4).
class AccessRequestsController < ApplicationController
  allow_unauthenticated_access only: :create

  # Rate limit básico como no auth (SessionsController): freia enxurrada/abuso.
  rate_limit to: 5, within: 1.minute, only: :create, with: :rate_limit_exceeded

  def create
    AccessRequest.record(**access_request_params)
    redirect_to root_path, notice: "Recebemos seu pedido — você será avisado se for aprovado."
  end

  private

  def access_request_params
    params.require(:access_request).permit(:email, :name, :note).to_h.symbolize_keys
  end

  def rate_limit_exceeded
    redirect_to root_path, alert: "Muitos pedidos. Aguarde um minuto."
  end
end
