# Dashboard web dos jobs (Solid Queue) via Mission Control — montado em
# /admin/jobs (rotas). Mesma postura do AhoyCaptain: engine de terceiro, com
# controller próprio, protegida por um gate "só admin".

# Desligamos o HTTP Basic embutido: a autenticação é a MESMA sessão assinada do
# app (magic-code), não um par usuário/senha à parte.
MissionControl::Jobs.http_basic_auth_enabled = false

# A engine herda deste controller base, que faz SÓ a autorização de admin
# (resolve a sessão assinada do app, exige admin). NÃO usamos o
# ApplicationController normal aqui: a concern Authentication dele redireciona
# pro sign_in_path com os helpers da engine (server_id) e estoura a rota. Ver
# app/controllers/admin/jobs_base_controller.rb.
MissionControl::Jobs.base_controller_class = "Admin::JobsBaseController"
