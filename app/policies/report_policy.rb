# Autorização do relatório (Fatia 5.1). O Report não é um Active Record e não tem
# `user_id` próprio — o isolamento (Q23) vive DENTRO do PORO (escopa `user.time_entries`
# pela bolha do Current.user). Aqui a regra é só "precisa estar logado": qualquer user
# autenticado vê o PRÓPRIO relatório, nunca o de outro (o Report não aceita user alheio).
class ReportPolicy < ApplicationPolicy
  def index?
    user.present?
  end
end
