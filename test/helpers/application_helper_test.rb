require "test_helper"

# Testa SÓ a nossa lógica do helper `icon` (Q80): re-emissão do SVG vendorizado com
# os defaults certos e erro claro pra nome errado. Views não se testam nesse nível.
class ApplicationHelperTest < ActionView::TestCase
  test "renderiza o svg inline com defaults (16px, aria-hidden, classe icon, currentColor)" do
    html = icon("timer")

    assert_match(/\A<svg /, html)
    assert_includes html, 'aria-hidden="true"'
    assert_includes html, 'width="16"'
    assert_includes html, 'height="16"'
    assert_includes html, 'class="icon"'
    assert_includes html, 'stroke="currentColor"'
    assert_includes html, "<circle" # miolo do timer.svg, sem escapar
    assert_not_includes html, "&lt;" # nada do miolo escapado
  end

  test "aceita size e mescla classe extra com a base" do
    html = icon("folder-open", size: 40, class: "icon--lg")

    assert_includes html, 'width="40"'
    assert_includes html, 'height="40"'
    assert_includes html, 'class="icon icon--lg"'
  end

  test "nome não vendorizado dá erro claro" do
    error = assert_raises(ArgumentError) { icon("nao-existe") }
    assert_match(/não vendorizado/, error.message)
  end

  test "rejeita nome fora do formato (sem path traversal)" do
    error = assert_raises(ArgumentError) { icon("../../config/master.key") }
    assert_match(/inválido/, error.message)
  end
end
