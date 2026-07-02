# Autorização de Task (Fatia 2.3). Herda o piso multi-tenant da ApplicationPolicy —
# a Task carrega `user_id` direto (Q23), então `relation_scope`/`manage?` funcionam
# igual a Client/Project sem refino. Existe pra o controller nomear a policy explícita.
class TaskPolicy < ApplicationPolicy
end
