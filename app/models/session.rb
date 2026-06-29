class Session < ApplicationRecord
  belongs_to :user

  # Identificada no cookie pelo signed_id do Rails (sem coluna token).
  # Ver app/controllers/concerns/authentication.rb.
end
