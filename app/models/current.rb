class Current < ActiveSupport::CurrentAttributes
  attribute :session, :user
  attribute :request_id, :user_agent, :ip_address

  # Ao setar a sessão, o usuário é resolvido em cascata (padrão fizzy).
  def session=(value)
    super
    self.user = value&.user
  end
end
