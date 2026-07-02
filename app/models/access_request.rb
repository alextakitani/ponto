class AccessRequest < ApplicationRecord
  # Pré-conta (Q24): pedido público de acesso, fora do isolamento por usuário.
  # O admin aprova/recusa depois (Task 1.4); aqui só registramos.
  normalizes :email, with: ->(value) { value.strip.downcase.presence }

  # Mesmo padrão de enum-string do resto do app (AccessToken).
  attribute :status, :string, default: "pending"
  enum :status, %w[pending approved rejected].index_by(&:itself)

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Registra um pedido de acesso sem revelar o resultado (anti-enumeração):
  #   - já existe User com o e-mail        -> não cria nada
  #   - já existe pedido pending com ele   -> atualiza a note, não duplica
  #   - caso contrário                     -> cria um pending novo
  # Sempre retorna sem sinalizar qual caso ocorreu.
  def self.record(email:, name: nil, note: nil)
    email = User.normalize_value_for(:email, email)

    if email.blank?
      # E-mail em branco/ausente: silêncio (o form pede e-mail; não revelamos nada).
    elsif User.exists?(email: email)
      # Já é conta: silêncio (o usuário simplesmente entra).
    elsif (existing = pending.find_by(email: email))
      existing.update(note: note)
    else
      # create (sem bang): e-mail malformado não estoura — só não registra.
      create(email: email, name: name, note: note)
    end
  end
end
