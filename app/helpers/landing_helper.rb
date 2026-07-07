module LandingHelper
  # Ordem canônica das telas na galeria "Veja por dentro". Cada shot só entra se o
  # asset existir (Propshaft) — a landing nunca mostra imagem quebrada, e a seção
  # inteira some enquanto nenhum screenshot foi capturado. As imagens vivem em
  # app/assets/images/landing/ (ex.: tracker.png). i18n em landing.gallery.shots.*.
  GALLERY_KEYS = %w[tracker reports projects export preferences].freeze

  def landing_gallery_shots
    GALLERY_KEYS.filter_map do |key|
      image = "landing/#{key}.png"
      { key: key, image: image } if landing_asset?(image)
    end
  end

  private
    def landing_asset?(logical_path)
      Rails.application.assets.load_path.find(logical_path).present?
    rescue StandardError
      false
    end
end
