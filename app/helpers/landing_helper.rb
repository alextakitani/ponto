module LandingHelper
  # Ordem canônica das telas na galeria "Veja por dentro". Cada shot só entra se o
  # asset existir (Propshaft) — a landing nunca mostra imagem quebrada, e a seção
  # inteira some enquanto nenhum screenshot foi capturado. As imagens vivem em
  # app/assets/images/landing/ (ex.: tracker.png / tracker-en.png). i18n em
  # landing.gallery.shots.*.
  GALLERY_KEYS = %w[tracker reports detailed projects export preferences].freeze

  # Landing bilíngue (Q79): em EN busca `<key>-en.png`, cai pra `<key>.png` (PT) se
  # a versão inglesa não existir. Assim a galeria acompanha o idioma da página.
  def landing_gallery_shots
    english = I18n.locale.to_s.start_with?("en")

    GALLERY_KEYS.filter_map do |key|
      image = landing_shot_image(key, english)
      { key: key, image: image } if image
    end
  end

  private
    def landing_shot_image(key, english)
      candidates = english ? [ "landing/#{key}-en.png", "landing/#{key}.png" ] : [ "landing/#{key}.png" ]
      candidates.find { |path| landing_asset?(path) }
    end

    def landing_asset?(logical_path)
      Rails.application.assets.load_path.find(logical_path).present?
    rescue StandardError
      false
    end
end
