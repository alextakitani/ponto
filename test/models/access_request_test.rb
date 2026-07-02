require "test_helper"

# Lógica nossa: normalização do e-mail (strip/downcase) e a regra de de-dup do
# `record` (não revela qual caso ocorreu). Validação declarativa não é testada.
class AccessRequestTest < ActiveSupport::TestCase
  test "normaliza o e-mail com strip e downcase antes de salvar" do
    request = AccessRequest.create!(email: "  Alex@Example.COM ")

    assert_equal "alex@example.com", request.email
  end

  test "record cria um pedido pending quando não há conta nem pedido" do
    assert_difference -> { AccessRequest.pending.count }, +1 do
      AccessRequest.record(email: "novo@example.com", name: "Novo", note: "por favor")
    end

    request = AccessRequest.pending.find_by(email: "novo@example.com")
    assert_equal "Novo", request.name
    assert_equal "por favor", request.note
  end

  test "record NÃO cria pedido quando já existe User com o e-mail" do
    create_user(email: "existe@example.com")

    assert_no_difference -> { AccessRequest.count } do
      AccessRequest.record(email: "Existe@example.com")
    end
  end

  test "record NÃO duplica quando já existe pedido pending; atualiza a note" do
    original = AccessRequest.record(email: "dup@example.com", note: "primeira")

    assert_no_difference -> { AccessRequest.count } do
      AccessRequest.record(email: "DUP@example.com", note: "segunda")
    end

    assert_equal "segunda", original.reload.note
  end

  test "record sempre devolve sem revelar o caso (nunca levanta)" do
    create_user(email: "conta@example.com")

    assert_nothing_raised do
      AccessRequest.record(email: "conta@example.com")
      AccessRequest.record(email: "livre@example.com")
      AccessRequest.record(email: "livre@example.com")
    end
  end

  test "record normaliza o e-mail ao casar com User existente" do
    create_user(email: "caps@example.com")

    assert_no_difference -> { AccessRequest.count } do
      AccessRequest.record(email: "  CAPS@Example.com  ")
    end
  end
end
