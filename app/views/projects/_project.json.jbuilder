# JSON de um Project (Q73). ESCALARES apenas (Q11): rate_cents/effective_rate_cents
# são int|null e currency/effective_currency string|null — NUNCA o objeto Money cru.
# effective_* já traz a cascata resolvida (Q22) pra o cliente CLI/extensão não re-resolver.
json.extract! project, :id, :name, :color, :client_id, :rate_cents, :archived_at, :created_at, :updated_at
json.currency project.effective_currency
json.effective_rate_cents project.effective_rate_cents
json.effective_currency project.effective_currency
