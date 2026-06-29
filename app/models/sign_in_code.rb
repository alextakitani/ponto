class SignInCode < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(consumed_at: nil).where("expires_at > ?", Time.current) }

  def expired?
    expires_at <= Time.current
  end

  def consumed?
    consumed_at.present?
  end

  def usable?
    !consumed? && !expired?
  end

  # Consome-e-destrói: marca como usado dentro de uma transação para garantir
  # uso único mesmo sob corrida. Decisões §3.
  def consume!
    with_lock do
      return false unless usable?
      update!(consumed_at: Time.current)
    end
    true
  end
end
