# Autorização de Client (Fatia 2.2). Herda TUDO do piso multi-tenant da
# ApplicationPolicy (Q23/Q40/Q41): o `relation_scope` filtra pra bolha do user do
# contexto e `manage?` nega record de outra conta comparando `user_id`. Não há regra
# fina no Client (ao contrário do Admin::UserPolicy, que barra auto-deleção) — o
# ownership base já é suficiente. Existe pra o controller nomear a policy explícita.
class ClientPolicy < ApplicationPolicy
end
