# Resolve o locale por request (Q79). Cadeia de precedência, em ordem:
#   1. params[:locale] válido -> usa E persiste na sessão.
#   2. session[:locale] válido -> usa.
#   3. Accept-Language do browser -> melhor match (en* -> :en, pt* -> :"pt-BR").
#   4. Senão/qualquer coisa inválida -> default (:"pt-BR").
#
# Um param inválido NUNCA estoura: cai silenciosamente na cadeia. Envolvemos a
# ação em I18n.with_locale para não vazar o locale entre requests (o I18n.locale
# é global por thread; with_locale restaura no ensure). O locale hardcoded do
# resto do app não é afetado — só a landing usa t().
module SetLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(resolve_locale, &action)
    end

    def resolve_locale
      locale_from_params || locale_from_session || locale_from_header || I18n.default_locale
    end

    # Regra 1: param válido persiste na sessão (a bandeirinha grava a escolha).
    def locale_from_params
      if locale = sanitize_locale(params[:locale])
        session[:locale] = locale.to_s
        locale
      end
    end

    # Regra 2: escolha anterior guardada na sessão.
    def locale_from_session
      sanitize_locale(session[:locale])
    end

    # Regra 3: melhor match do Accept-Language. Parsing simples e robusto: quebra
    # o header em pares idioma;q=peso, ordena por peso desc e pega o 1º cujo
    # PREFIXO de idioma casa com um locale disponível (en* -> :en, pt* -> :"pt-BR").
    def locale_from_header
      preferred_languages.each do |language|
        if locale = available_locales.find { |available| language.start_with?(language_prefix(available)) }
          return locale
        end
      end
      nil
    end

    def preferred_languages
      header = request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
      header
        .split(",")
        .map { |part| parse_language_tag(part) }
        .compact
        .sort_by { |_language, quality| -quality }
        .map { |language, _quality| language }
    end

    # "pt-BR;q=0.9" -> ["pt", 0.9]. Sem q -> peso 1.0. Descarta lixo.
    def parse_language_tag(part)
      tag, *params = part.strip.split(";")
      language = tag.to_s.downcase.split("-").first
      return nil if language.blank?

      quality = params.find { |p| p.strip.start_with?("q=") }&.then { |p| p.split("=", 2).last.to_f } || 1.0
      [ language, quality ]
    end

    def language_prefix(locale)
      locale.to_s.downcase.split("-").first
    end

    def sanitize_locale(value)
      candidate = value.to_s
      available_locales.find { |locale| locale.to_s == candidate } if candidate.present?
    end

    def available_locales
      I18n.available_locales
    end
end
