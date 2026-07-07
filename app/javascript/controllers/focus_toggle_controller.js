import { Controller } from "@hotwired/stimulus"

// Elementos que revelam algo no :focus (descrição truncada expande, decorrido
// mostra o valor) não têm como REVERTER por CSS puro: o foco fica até clicar
// fora. Aqui o 2º clique/tap desfoca: o pointerdown dispara ANTES de o foco
// mover, então dá pra saber se o elemento JÁ estava focado — nesse caso o click
// seguinte chama blur(). Teclado (Tab/Esc) não passa por aqui e segue intacto.
export default class extends Controller {
  pointerdown() {
    this.wasFocused = document.activeElement === this.element
  }

  click() {
    if (this.wasFocused) this.element.blur()
    this.wasFocused = false
  }
}
