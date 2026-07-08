module AdminHelper
  # Rótulo em PT do status derivado da conta (Q31).
  def user_status_label(user)
    t("admin.users.statuses.#{user.status}")
  end

  # properties do ahoy_event é text (JSON serializado). Parseia de forma segura
  # pra view do api_usage — evita estourar se algum evento vier malformado.
  def admin_api_usage_properties(event)
    JSON.parse(event.properties.to_s)
  rescue JSON::ParserError
    {}
  end
end
