require "test_helper"

# Guarda-costas da Q79 (app bilíngue): em runtime o fallback pt-BR mascara chave
# faltante no en (devolve português em página inglesa SEM levantar erro — o
# raise_on_missing_translations só dispara quando falta nos DOIS). A paridade
# dos ymls é disciplina manual; este teste a torna executável (review de i18n).
class I18nKeysTest < ActiveSupport::TestCase
  PAIRS = {
    "pt-BR.yml" => "en.yml",
    "activerecord.pt-BR.yml" => "activerecord.en.yml"
  }.freeze

  PAIRS.each do |pt_file, en_file|
    test "#{pt_file} e #{en_file} têm exatamente as mesmas chaves" do
      pt = flatten_keys(load_locale(pt_file, "pt-BR"))
      en = flatten_keys(load_locale(en_file, "en"))

      assert_equal [], pt - en, "Chaves só no #{pt_file} (faltam no #{en_file})"
      assert_equal [], en - pt, "Chaves só no #{en_file} (faltam no #{pt_file})"
    end
  end

  private
    def load_locale(file, root)
      YAML.load_file(Rails.root.join("config/locales", file)).fetch(root)
    end

    # Achata a árvore em "a.b.c"; formas de plural (one/other/...) colapsam no
    # pai — idiomas podem legitimamente ter categorias de plural diferentes.
    PLURAL_KEYS = %w[zero one two few many other].freeze

    def flatten_keys(hash, prefix = nil)
      hash.flat_map { |key, value|
        path = [ prefix, key.to_s ].compact.join(".")
        if value.is_a?(Hash)
          plural = value.keys.map(&:to_s).all? { |k| PLURAL_KEYS.include?(k) }
          plural ? [ prefix ] : flatten_keys(value, path)
        else
          [ path ]
        end
      }.uniq.sort
    end
end
