import { Controller } from "@hotwired/stimulus"

// Aplica o tema NA HORA no <body> (data-theme) quando o <select> de tema muda, sem
// esperar o round-trip. A persistência em User.theme vai pelo PATCH do form (o
// settings_select submete no change) — aqui só damos o feedback visual imediato.
// "system" remove o override pra o prefers-color-scheme voltar a mandar (igual ao
// layout app.html.erb).
export default class extends Controller {
  static targets = ["select"]

  apply() {
    const theme = this.hasSelectTarget ? this.selectTarget.value : null
    if (!theme) return

    const body = document.body
    if (theme === "system") {
      delete body.dataset.theme
    } else {
      body.dataset.theme = theme
    }
  }
}
