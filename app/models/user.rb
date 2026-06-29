class User < ApplicationRecord
  has_many :sessions, dependent: :destroy
  has_many :sign_in_codes, dependent: :destroy
  has_many :access_tokens, dependent: :destroy

  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Bearer escopado por método HTTP (decisões §3, padrão fizzy).
  def self.find_by_permissable_access_token(token, method:)
    access_token = AccessToken.find_by(token: token)
    return unless access_token&.allows?(method)

    access_token.touch_usage!
    access_token.user
  end

  # Emite um código de 6 dígitos, manda por e-mail e devolve o SignInCode
  # (em dev o controller usa o código em claro p/ servir via flash/header).
  #
  # O código em claro vai como argumento pro mailer (não via record): deliver_later
  # serializa o SignInCode e o recarrega no job, perdendo o atributo transiente.
  def send_sign_in_code
    sign_in_codes.create!.tap do |sign_in_code|
      SignInMailer.with(user: self, code: sign_in_code.code).code.deliver_later
    end
  end
end
