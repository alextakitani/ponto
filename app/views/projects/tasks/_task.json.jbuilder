# JSON de uma Task (Q73). Escalares simples — sem dinheiro aqui (a rate vive no
# projeto). project_id pra o cliente CLI saber a que projeto pertence.
json.extract! task, :id, :name, :project_id, :archived_at, :created_at, :updated_at
