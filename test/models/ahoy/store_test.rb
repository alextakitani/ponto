require "test_helper"

# Ahoy::Store.iso_country: o AhoyCaptain indexa mapa e bandeiras por ISO ("BR"),
# não pelo nome ("Brazil"). Testamos NOSSA transformação (o super que persiste é
# framework do Ahoy).
class Ahoy::StoreTest < ActiveSupport::TestCase
  test "iso_country troca o nome do país pelo ISO code quando há country_code" do
    data = Ahoy::Store.iso_country(country: "Brazil", country_code: "BR", city: "São Paulo")

    assert_equal "BR", data[:country]
    assert_equal "São Paulo", data[:city] # demais campos intactos
  end

  test "iso_country mantém o country quando não há country_code (não quebra)" do
    data = Ahoy::Store.iso_country(country: "Brazil")

    assert_equal "Brazil", data[:country]
  end

  test "iso_country ignora country_code vazio" do
    data = Ahoy::Store.iso_country(country: "Brazil", country_code: "")

    assert_equal "Brazil", data[:country]
  end
end
