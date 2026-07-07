require "test_helper"

# Testa SÓ a lógica NOSSA do tooltip do "Registrado": seleção das 3 unidades mais
# significativas e pluralização via I18n (as conversões ano/mês são do ActiveSupport,
# não re-testamos o framework).
class ProjectsHelperTest < ActionView::TestCase
  test "registered_words mostra as unidades significativas em pt-BR" do
    assert_equal "1 dia 1 hora", project_registered_words(25.hours.to_i)
    assert_equal "2 horas 30 minutos", project_registered_words((2.hours + 30.minutes).to_i)
    assert_equal "45 segundos", project_registered_words(45)
  end

  test "registered_words corta na 3ª unidade mais significativa" do
    # 1 dia, 1 hora, 1 minuto e 1 segundo → o segundo (4ª unidade) fica de fora.
    assert_equal "1 dia 1 hora 1 minuto", project_registered_words(90_061)
  end
end
