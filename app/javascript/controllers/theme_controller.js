import { Controller } from "@hotwired/stimulus"

// Aplica o tema NA HORA no <body> (data-theme), sem esperar o round-trip. A
// persistência em User.theme vai por um form Turbo (button_to) em paralelo — aqui
// só damos o feedback visual imediato e marcamos o botão ativo. "system" remove o
// override pra o prefers-color-scheme voltar a mandar (igual ao layout app.html.erb).
export default class extends Controller {
  static values = { current: String }
  static targets = ["option"]

  apply(event) {
    const theme = event.params.theme
    const body = document.body

    if (theme === "system") {
      delete body.dataset.theme
    } else {
      body.dataset.theme = theme
    }

    this.currentValue = theme
    this.#markActive(theme)
  }

  #markActive(theme) {
    this.optionTargets.forEach((option) => {
      const active = option.dataset.themeThemeParam === theme
      option.classList.toggle("is-active", active)
      option.setAttribute("aria-pressed", active ? "true" : "false")
    })
  }
}
