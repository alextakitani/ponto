class AccessToken < ApplicationRecord
  belongs_to :user

  has_secure_token :token

  validates :http_methods, presence: true

  # "GET,POST" -> ["GET", "POST"]
  def allowed_methods
    http_methods.to_s.upcase.split(",").map(&:strip).reject(&:blank?)
  end

  def allows?(http_method)
    allowed_methods.include?(http_method.to_s.upcase)
  end

  def touch_usage!
    update_column(:last_used_at, Time.current)
  end
end
