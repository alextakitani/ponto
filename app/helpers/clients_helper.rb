module ClientsHelper
  # Opções do select de moeda (Q42). BRL/USD/EUR no topo (as comuns aqui), depois o
  # resto do catálogo do gem money em ordem alfabética. Value = ISO code em upcase
  # (o que a coluna guarda, já normalizado no model).
  TOP_CURRENCIES = %w[BRL USD EUR].freeze

  # Rate formatada do cliente, ou "—" quando sem taxa (rate nil — Q2/Q15).
  def client_rate(client)
    if client.rate_cents
      humanized_money_with_symbol(client.rate)
    else
      t("common.none")
    end
  end

  # Valor do campo `rate` no form de edição, em pt-BR ("150,00") — casa com o input
  # do usuário e round-trips pelo normalize_rate_input do model. nil = campo vazio.
  def rate_field_value(client)
    if client.rate_cents
      I18n.with_locale(:"pt-BR") { number_with_precision(client.rate.amount, precision: 2, delimiter: ".", separator: ",") }
    end
  end

  def currency_options
    top = TOP_CURRENCIES.map { |code| [ currency_label(code), code ] }

    rest = Money::Currency.all
      .map { |c| c.iso_code }
      .reject { |code| TOP_CURRENCIES.include?(code) }
      .sort
      .map { |code| [ currency_label(code), code ] }

    top + rest
  end

  private
    def currency_label(code)
      currency = Money::Currency.find(code)
      currency ? "#{code} — #{currency.name}" : code
    end
end
