# Autorização da fila de pedidos de acesso (Q35). Só admin aprova/recusa; herda o
# piso "tem que ser admin" da base — nada a refinar aqui.
class Admin::AccessRequestPolicy < Admin::BasePolicy
end
