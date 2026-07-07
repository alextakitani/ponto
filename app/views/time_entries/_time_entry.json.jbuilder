# JSON de uma TimeEntry (Q73). Escalares apenas: ids, timestamps, cents, currency,
# booleans e derivados numéricos — nunca o objeto Money cru.
json.extract! time_entry, :id, :project_id, :task_id, :description, :started_at, :ended_at, :rate_cents, :currency, :billable
json.duration_seconds time_entry.duration_seconds
json.billable_amount_cents time_entry.billable_amount&.cents

# Tags da entry (07/07): a extensão e a CLI DEFINIAM tags mas não conseguiam EXIBIR
# as de uma entry existente — o JSON não as retornava. `tag_ids` pra lógica; `tags`
# (id + name) pra exibição sem uma 2ª request. Ambos ordenados por nome (mesma
# ordem → determinístico e casado entre os dois campos).
ordered_tags = time_entry.tags.sort_by(&:name_normalized)
json.tag_ids ordered_tags.map(&:id)
json.tags ordered_tags do |tag|
  json.extract! tag, :id, :name
end
