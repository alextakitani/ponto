# JSON de uma TimeEntry (Q73). Escalares apenas: ids, timestamps, cents, currency,
# booleans e derivados numéricos — nunca o objeto Money cru.
json.extract! time_entry, :id, :project_id, :task_id, :description, :started_at, :ended_at, :rate_cents, :currency, :billable
json.duration_seconds time_entry.duration_seconds
json.billable_amount_cents time_entry.billable_amount&.cents
