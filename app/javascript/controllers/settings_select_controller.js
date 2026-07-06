import { Controller } from "@hotwired/stimulus"

// Submete o form no change de um <select> — sem botão "salvar". Usado nos ajustes
// rápidos (idioma/tema) da welcome: escolher a opção já dispara o PATCH.
export default class extends Controller {
  static targets = ["localeField"]

  submit(event) {
    // Idioma: a página tem que recarregar JÁ no locale novo, então o return_to
    // (hidden) recebe o welcome_path com ?locale=<escolhido> antes de submeter.
    if (this.hasLocaleFieldTarget && event.target === this.localeFieldTarget) {
      const returnTo = this.element.querySelector("input[name='return_to']")
      if (returnTo) {
        const base = returnTo.value.split("?")[0]
        returnTo.value = `${base}?locale=${encodeURIComponent(this.localeFieldTarget.value)}`
      }
    }

    this.element.requestSubmit()
  }
}
