module ApplicationHelper
  include Pagy::Frontend

  # Ícones Lucide (Q80) — vendorizados como SVG puro em app/assets/svg/icons/
  # (licença ISC — LICENSE na mesma pasta). Sem gem, sem lucide.js.
  #
  # Arquitetura: arquivos .svg intactos (byte a byte do upstream, fáceis de
  # atualizar/auditar) + este helper, que lê o miolo (paths) UMA vez por processo
  # e re-emite o <svg> inline com os nossos atributos. Inline porque o ícone herda
  # a cor do texto via currentColor (claro/escuro de graça — um <img> não herdaria)
  # e não precisa de digest/URL: nunca é servido, só embutido no HTML.
  #
  # Uso: ícone SEMPRE acompanha um label visível (Q63 — hierarquia por tipografia;
  # o ícone é apoio), por isso aria-hidden=true por padrão. Botão compacto sem
  # label visível (ex.: o ⋮ dos menus) precisa de aria-label no PRÓPRIO botão.
  ICON_DIR = Rails.root.join("app/assets/svg/icons")
  ICON_NAME_FORMAT = /\A[a-z0-9-]+\z/
  ICON_CACHE = {} # cache name => miolo do SVG, imutável depois de carregado

  def icon(name, size: 16, **options)
    tag.svg icon_inner_markup(name.to_s),
      xmlns: "http://www.w3.org/2000/svg",
      viewBox: "0 0 24 24",
      width: size,
      height: size,
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
      class: class_names("icon", options.delete(:class)),
      aria: { hidden: true },
      **options
  end

  private
    def icon_inner_markup(name)
      ICON_CACHE[name] ||= read_icon(name)
    end

    def read_icon(name)
      unless name.match?(ICON_NAME_FORMAT)
        raise ArgumentError, "Nome de ícone inválido: #{name.inspect} (esperado kebab-case, ex.: \"chart-column\")"
      end

      path = ICON_DIR.join("#{name}.svg")
      unless path.exist?
        raise ArgumentError, "Ícone Lucide não vendorizado: #{name.inspect} — baixe o SVG para app/assets/svg/icons/"
      end

      # Todo ícone Lucide compartilha o MESMO wrapper (24×24, stroke currentColor…),
      # que o `icon` re-emite; daqui extraímos só o miolo (os paths).
      path.read[%r{<svg[^>]*>(.*)</svg>}m, 1].strip.html_safe
    end
end
