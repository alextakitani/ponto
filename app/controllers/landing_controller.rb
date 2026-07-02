# Landing pública de uma dobra (Q67): apresenta o Ponto + form "pedir acesso".
# Logado não vê a landing — cai direto na home (é pra onde o login volta, via
# after_authentication_url -> root_url).
class LandingController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    if authenticated?
      # TODO: quando a home de domínio (tracker /time_entries) existir, apontar
      # o redirect pra ela em vez do placeholder.
      redirect_to home_path
    else
      @operator_setup_needed = operator_setup_needed?
    end
  end

  private

  # Estado especial (Q38): sem NENHUMA conta e sem ADMIN_EMAIL configurado, o
  # app ainda não pode nem convidar o admin — mostramos um aviso de operador no
  # lugar do form de pedir acesso.
  def operator_setup_needed?
    User.none? && ENV["ADMIN_EMAIL"].blank?
  end
end
