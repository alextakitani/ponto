# Autorização do histórico de imports do Clockify. Herda o piso multi-tenant da
# ApplicationPolicy: escopo por user na coleção e ownership por `user_id` no record.
class ClockifyImportPolicy < ApplicationPolicy
end
