# JSON de um Client (Q73). ESCALARES apenas — rate_cents (int|null) + currency
# (string), NUNCA o objeto Money cru (Q11).
json.extract! client, :id, :name, :rate_cents, :currency, :note, :archived_at, :created_at, :updated_at
