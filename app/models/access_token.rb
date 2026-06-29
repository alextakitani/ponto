class AccessToken < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  # Escopo do token (decisões §3). read = só leitura; write = leitura + escrita.
  attribute :permission, :string, default: "read"
  enum :permission, %w[read write].index_by(&:itself)

  # GET/HEAD são sempre permitidos (leitura). Métodos de escrita exigem :write.
  def allows?(http_method)
    http_method.to_s.upcase.in?(%w[GET HEAD]) || write?
  end

  def touch_usage!
    update_column(:last_used_at, Time.current)
  end
end
