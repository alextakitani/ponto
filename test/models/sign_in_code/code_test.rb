require "test_helper"

# Lógica nossa: gerar código de N dígitos e tolerar o que o humano digita.
class SignInCode::CodeTest < ActiveSupport::TestCase
  test "generate produz exatamente N dígitos, com zeros à esquerda" do
    20.times do
      code = SignInCode::Code.generate(6)
      assert_match(/\A\d{6}\z/, code)
    end
  end

  test "sanitize remove espaços, traços e qualquer não-dígito" do
    assert_equal "123456", SignInCode::Code.sanitize(" 123-456 ")
    assert_equal "123456", SignInCode::Code.sanitize("12.34.56")
    assert_equal "987654", SignInCode::Code.sanitize("987abc654")
  end

  test "sanitize devolve nil quando não sobra nenhum dígito" do
    assert_nil SignInCode::Code.sanitize("   ")
    assert_nil SignInCode::Code.sanitize("abc")
    assert_nil SignInCode::Code.sanitize(nil)
  end
end
