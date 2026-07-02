module ProjectsHelper
  # Rate EFETIVA do projeto formatada (override ou herdada — Q22), ou "—" quando não
  # há rate (Q2). Força pt-BR (a UI interna é sempre pt-BR; Money.locale_backend segue
  # o request → forçamos aqui, mesmo racional do client_rate). Usa a currency efetiva.
  def project_effective_rate(project)
    cents = project.effective_rate_cents
    if cents
      money = Money.new(cents, project.effective_currency)
      # `.format` (não humanized_money_with_symbol) pra SEMPRE mostrar as casas decimais
      # ("R$ 150,00", não "R$ 150"). Força pt-BR (a UI interna é sempre pt-BR; o
      # Money.locale_backend seguiria o request → forçamos, mesmo racional do client_rate).
      I18n.with_locale(:"pt-BR") { money.format }
    else
      "—"
    end
  end

  # Valor do campo `rate` (override) no form, em pt-BR ("150,00") — casa com o input do
  # usuário e round-trips pelo writer do model. nil = campo vazio (herda — Q45).
  def project_rate_field_value(project)
    if project.rate_cents
      money = Money.new(project.rate_cents, project.effective_currency || Project::FALLBACK_CURRENCY)
      I18n.with_locale(:"pt-BR") { number_with_precision(money.amount, precision: 2, delimiter: ".", separator: ",") }
    end
  end

  # Rate formatada de um CLIENTE (pra o placeholder herdado do form — Q45). nil sem taxa.
  def client_inherited_rate(client)
    if client&.rate_cents
      money = Money.new(client.rate_cents, client.currency)
      I18n.with_locale(:"pt-BR") { money.format }
    end
  end

  # Mapa client_id → rate formatada, serializado pro Stimulus (rate_inheritance) montar
  # o placeholder ao vivo quando o select de cliente muda (Q45). Só clientes do form.
  def client_rates_map(clients)
    clients.each_with_object({}) do |client, map|
      map[client.id] = client_inherited_rate(client)
    end.to_json
  end

  # Texto auxiliar do campo de rate no ESTADO INICIAL do form (Q45). O Stimulus
  # recalcula a MESMA lógica ao vivo quando o cliente muda (as três frases têm que
  # bater — model, helper e JS). Casos: sem cliente · cliente sem taxa · cliente com taxa.
  def project_rate_hint(project)
    rate = client_inherited_rate(project.client)
    if project.client.nil?
      "Sem cliente → defina um valor ou o projeto fica sem taxa."
    elsif rate.nil?
      "Este cliente não tem taxa → defina um valor ou o projeto fica sem taxa."
    else
      "Herdando do cliente: #{rate} — preencha para sobrescrever."
    end
  end
end
