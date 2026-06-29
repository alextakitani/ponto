class SignInCode < ApplicationRecord
  CODE_LENGTH = 6
  EXPIRATION_TIME = 15.minutes

  belongs_to :user

  # Código em claro disponível só logo após gerar (mailer + dev). No banco
  # guardamos só o digest — uso único + expiração curta + rate limit (decisões §3).
  attr_reader :code

  scope :active, -> { where(consumed_at: nil).where(expires_at: Time.current...) }

  before_validation :generate_code, on: :create
  before_validation :set_expiration, on: :create

  validates :code_digest, presence: true

  class << self
    # Encontra um código ativo do usuário que bata com o dígito informado e o
    # consome (uso único). Devolve o registro consumido ou nil.
    def consume(user, raw_code)
      digest = digest_for(raw_code)
      return if digest.nil?

      user.sign_in_codes.active.find_by(code_digest: digest)&.consume
    end

    def digest_for(raw_code)
      sanitized = Code.sanitize(raw_code)
      Digest::SHA256.hexdigest(sanitized) if sanitized.present?
    end
  end

  # Consome-e-destrói: marca usado sob lock p/ garantir uso único na corrida.
  def consume
    with_lock do
      return if consumed_at.present? || expired?
      update!(consumed_at: Time.current)
    end
    self
  end

  def expired?
    expires_at <= Time.current
  end

  private

  def generate_code
    @code ||= Code.generate(CODE_LENGTH)
    self.code_digest ||= Digest::SHA256.hexdigest(@code)
  end

  def set_expiration
    self.expires_at ||= EXPIRATION_TIME.from_now
  end
end
