# Autorização de Project (Fatia 2.3). Herda o piso multi-tenant da ApplicationPolicy
# (Q23/Q40/Q41): `relation_scope` filtra pra bolha do user e `manage?` nega record de
# outra conta por `user_id`. Sem regra fina própria — o ownership base basta (o
# cliente-do-mesmo-user é validação de MODEL, não de policy). Existe pra o controller
# nomear a policy explícita, como o ClientPolicy.
class ProjectPolicy < ApplicationPolicy
end
