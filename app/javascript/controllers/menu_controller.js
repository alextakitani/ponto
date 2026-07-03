import { Controller } from "@hotwired/stimulus"

// Light-dismiss pra menus feitos com <details> (linhas de Clients/Projects/Tasks e
// painel admin). O <details> nativo NÃO fecha ao clicar fora nem no Escape — este
// controller adiciona esse comportamento SEM substituir o <details> (ele continua
// funcionando sem JS; o Stimulus só melhora o dismiss). Anexar com data-controller="menu".
export default class extends Controller {
  connect() {
    // Guardamos as referências ligadas pra poder removê-las no disconnect (senão
    // vazam listeners quando o Turbo troca o DOM).
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("click", this.closeOnOutsideClick)
    this.element.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    this.element.removeEventListener("keydown", this.closeOnEscape)
  }

  // (a) Clique/tap FORA do <details> aberto → fecha. Cliques dentro (incluindo o
  // summary e os itens) não fecham por aqui.
  closeOnOutsideClick(event) {
    if (this.element.open && !this.element.contains(event.target)) {
      this.element.open = false
    }
  }

  // (b) Escape fecha e devolve o foco ao summary (acessibilidade — o usuário volta
  // pro gatilho, não perde o lugar).
  closeOnEscape(event) {
    if (event.key === "Escape" && this.element.open) {
      const nestedOpen = Array.from(this.element.querySelectorAll("details[open]"))
        .find((details) => details !== this.element && details.contains(event.target))

      if (nestedOpen) {
        event.preventDefault()
        event.stopPropagation()
        nestedOpen.open = false
        nestedOpen.querySelector("summary")?.focus()
        return
      }

      this.element.open = false
      this.element.querySelector("summary")?.focus()
    }
  }
}
