import { Controller } from "@hotwired/stimulus"

// Substitui o confirm() nativo do Turbo por um <dialog> com o estilo do app
// (técnica boringrails). Registra o handler global uma vez, quando o dialog conecta;
// cada turbo_confirm passa a abrir este modal. A Promise resolve pelo returnValue do
// <dialog> — "confirm" quando o form method=dialog submete, senão cancelado (Esc,
// clique fora, botão Cancelar). Fallback pro confirm() nativo se algo faltar.
export default class extends Controller {
  static targets = [ "message", "confirm" ]

  connect() {
    if (!window.Turbo?.config?.forms) return

    window.Turbo.config.forms.confirm = (message, _element, submitter) => {
      if (!this.hasMessageTarget) return Promise.resolve(window.confirm(message))

      this.messageTarget.textContent = message
      // O gatilho pode customizar o rótulo do botão de confirmar (ex.: "Deletar").
      const label = submitter?.dataset?.turboConfirmButton
      if (label && this.hasConfirmTarget) this.confirmTarget.textContent = label

      this.element.showModal()

      return new Promise((resolve) => {
        this.element.addEventListener(
          "close",
          () => resolve(this.element.returnValue === "confirm"),
          { once: true }
        )
      })
    }
  }
}
