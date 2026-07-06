import { Controller } from "@hotwired/stimulus"

// Guarda de form sujo: avisa antes de PERDER edição não salva (feedback do dono —
// criar tag inline e sair sem Salvar descartava tudo em silêncio). Stimulus é o
// nível certo aqui (regra Frame→Stream→Stimulus): estado sujo é do browser, nem
// Frame nem Stream têm como saber.
//
// Cobre as três saídas: fechar/recarregar a aba (beforeunload nativo), navegação
// Turbo pra outra tela (turbo:before-visit) e o Cancelar do form inline (link com
// data-action="dirty-form#confirmLeave"). Submeter limpa a flag — salvar não avisa.
export default class extends Controller {
  static values = { message: String }

  connect() {
    this.dirty = false
    this.boundBeforeUnload = this.beforeUnload.bind(this)
    this.boundBeforeVisit = this.beforeVisit.bind(this)
    window.addEventListener("beforeunload", this.boundBeforeUnload)
    document.addEventListener("turbo:before-visit", this.boundBeforeVisit)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.boundBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.boundBeforeVisit)
  }

  // data-action="change->dirty-form#markDirty input->dirty-form#markDirty" no form.
  markDirty() {
    this.dirty = true
  }

  // data-action="submit->dirty-form#allowLeave" — salvar segue sem aviso.
  allowLeave() {
    this.dirty = false
  }

  // O link Cancelar (dentro do form) pede confirmação quando há mudanças.
  confirmLeave(event) {
    if (this.dirty && !window.confirm(this.messageValue)) {
      event.preventDefault()
    }
  }

  beforeVisit(event) {
    if (this.dirty && !window.confirm(this.messageValue)) {
      event.preventDefault()
    }
  }

  beforeUnload(event) {
    if (this.dirty) {
      event.preventDefault()
      // O browser mostra o prompt nativo dele (a string custom é ignorada hoje).
      event.returnValue = ""
    }
  }
}
