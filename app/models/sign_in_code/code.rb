# Geração e normalização do código de 6 dígitos (decisões §3).
# Variante "só dígitos" do MagicLink::Code do fizzy.
module SignInCode::Code
  class << self
    def generate(length)
      format("%0#{length}d", SecureRandom.random_number(10**length))
    end

    # Tolera o que o humano digita: tira espaços/traços e qualquer não-dígito.
    def sanitize(code)
      code.to_s.gsub(/\D/, "").presence
    end
  end
end
