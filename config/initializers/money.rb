# Configuração do money-rails (Q11/Q20). Dinheiro em Ruby puro, sem Node.
#
# ⚠️ REGRA DO PROJETO: NUNCA serializar um objeto `Money` cru em JSON — vira um hash
# gigante e vaza formatação. Nas rotas de API/extensão, exponha ESCALARES:
# `rate_cents` (integer) + `currency` (string). Ver CLAUDE.md "Convenções".
MoneyRails.configure do |config|
  # BRL é a moeda default do app; a moeda real de cada valor mora na coluna
  # `currency` do model (`monetize ..., with_model_currency: :currency`).
  config.default_currency = :brl

  # Arredondamento no centavo, HALF_UP (Q11): dinheiro sempre fecha no centavo, e o
  # ".5" sobe. Vale pra faturável = horas × rate.
  config.rounding_mode = BigDecimal::ROUND_HALF_UP
end

# Formatação segue o locale da UI (pt-BR): "R$ 1.234,56". A UI é pt-BR, então o
# backend de locale é o do i18n (não o embutido da gem money). As chaves Rails de
# número/moeda que fazem esse "R$ 1.234,56" acontecer vivem em
# `config/locales/numbers.pt-BR.yml` — sem elas o gem cairia no fallback
# ("R$1234.56").
Money.locale_backend = :i18n
