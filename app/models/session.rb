class Session < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  # Conveniência para gravar metadados da request na criação.
  def self.start_for(user, request)
    create!(
      user:       user,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
  end
end
