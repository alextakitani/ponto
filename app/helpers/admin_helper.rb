module AdminHelper
  # Rótulo em PT do status derivado da conta (Q31).
  def user_status_label(user)
    t("admin.users.statuses.#{user.status}")
  end
end
