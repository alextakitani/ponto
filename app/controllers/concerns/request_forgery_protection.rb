# Proteção CSRF, com isenção pontual para a extensão de Chrome (decisões §9).
#
# O fizzy usa `protect_from_forgery using: :header_only`, mas essa estratégia só
# existe no Rails edge. No Rails 8.1 obtemos o mesmo efeito tratando como
# "verified" os requests que são claramente da extensão: JSON + Authorization
# Bearer. Esses já são autenticados pelo AccessToken (escopado por método), então
# não precisam de token CSRF — e nenhuma navegação de browser carrega Bearer.
module RequestForgeryProtection
  extend ActiveSupport::Concern

  included do
    protect_from_forgery with: :exception
  end

  private

  def verified_request?
    super || bearer_api_request?
  end

  def bearer_api_request?
    request.format.json? && request.authorization.to_s.start_with?("Bearer ")
  end
end
