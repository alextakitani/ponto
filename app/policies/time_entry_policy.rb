# Autorização de TimeEntry (Fatia 3.1). Herda o piso multi-tenant da
# ApplicationPolicy (Q23/Q40/Q41): `relation_scope` filtra pra bolha do user e
# `manage?` compara `user_id` do record.
class TimeEntryPolicy < ApplicationPolicy
end
