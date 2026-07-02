module AdminHelper
  # Rótulo em PT do status derivado da conta (Q31).
  def user_status_label(user)
    { invited: "Convidado", active: "Ativo", suspended: "Suspenso" }.fetch(user.status)
  end
end
