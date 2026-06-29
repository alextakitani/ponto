class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :sign_in_codes, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Emite um código de 6 dígitos, guarda só o digest, devolve o código em claro
  # para o mailer. Expira em 15 min, uso único. Decisões §3.
  def issue_sign_in_code
    code = format("%06d", SecureRandom.random_number(1_000_000))
    sign_in_codes.create!(
      code_digest: self.class.digest_code(code),
      expires_at:  15.minutes.from_now
    )
    code
  end

  def self.digest_code(code)
    Digest::SHA256.hexdigest(code.to_s)
  end
end
