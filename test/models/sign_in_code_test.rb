require "test_helper"

# Lógica nossa: uso único, expiração e que só o digest é persistido.
class SignInCodeTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "guarda só o digest; o código em claro é transiente (some no reload)" do
    sic = @user.send_sign_in_code
    assert_match(/\A\d{6}\z/, sic.code)
    assert_not_equal sic.code, sic.code_digest
    assert_nil SignInCode.find(sic.id).code
  end

  test "consume aceita o código (tolerando lixo de digitação) e marca usado" do
    sic = @user.send_sign_in_code
    consumed = SignInCode.consume(@user, " #{sic.code[0..2]}-#{sic.code[3..5]} ")

    assert_equal sic.id, consumed.id
    assert consumed.consumed_at.present?
  end

  test "uso único: o segundo consume do mesmo código devolve nil" do
    sic = @user.send_sign_in_code
    assert SignInCode.consume(@user, sic.code)
    assert_nil SignInCode.consume(@user, sic.code)
  end

  test "código expirado não é consumível" do
    sic = @user.send_sign_in_code
    sic.update!(expires_at: 1.second.ago)

    assert_nil SignInCode.consume(@user, sic.code)
  end

  test "consume é escopado ao usuário: código de outro usuário não serve" do
    other = create_user(email: "other@example.com")
    sic = @user.send_sign_in_code

    assert_nil SignInCode.consume(other, sic.code)
  end

  test "consume sob corrida: só uma thread vence (uso único garantido por lock)" do
    sic = @user.send_sign_in_code
    results = Concurrent::Array.new

    threads = 5.times.map do
      Thread.new { results << SignInCode.consume(@user, sic.code) }
    end
    threads.each(&:join)

    assert_equal 1, results.compact.size, "exatamente uma thread deve consumir o código"
  end
end
