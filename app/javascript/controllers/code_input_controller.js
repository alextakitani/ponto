import { Controller } from "@hotwired/stimulus"

// Entrada do magic code em 6 caixas (uma por dígito). Genuinamente client-side
// (teclado dígito-a-dígito, colar dividido, auto-submit) — Frame/Stream não
// resolvem. Mantém um campo escondido `code` com o valor concatenado, que é o
// que o form realmente envia. Ao completar os 6 dígitos, submete sozinho.
export default class extends Controller {
  static targets = ["box", "hidden"]

  connect() {
    // Só dígitos e no máximo 1 char por caixa já vêm do markup (maxlength/inputmode);
    // aqui garantimos foco inicial na primeira caixa vazia.
    this.focusFirstEmpty()
  }

  // Digitou numa caixa: fica só o último dígito, avança o foco e sincroniza.
  input(event) {
    const box = event.target
    const digit = box.value.replace(/\D/g, "").slice(-1)
    box.value = digit

    if (digit) this.focusNext(box)
    this.sync()
  }

  // Backspace numa caixa vazia volta pra anterior (apagando o dígito de lá).
  keydown(event) {
    const box = event.target

    if (event.key === "Backspace" && box.value === "") {
      const prev = this.previousBox(box)
      if (prev) {
        prev.value = ""
        prev.focus()
        event.preventDefault()
        this.sync()
      }
    } else if (event.key === "ArrowLeft") {
      this.previousBox(box)?.focus()
    } else if (event.key === "ArrowRight") {
      this.nextBox(box)?.focus()
    }
  }

  // Colar em QUALQUER caixa distribui os dígitos por todas e tenta o login.
  paste(event) {
    event.preventDefault()
    const digits = (event.clipboardData?.getData("text") || "")
      .replace(/\D/g, "")
      .slice(0, this.boxTargets.length)

    if (!digits) return

    this.boxTargets.forEach((box, i) => (box.value = digits[i] || ""))
    this.sync()

    const lastFilled = Math.min(digits.length, this.boxTargets.length) - 1
    this.boxTargets[lastFilled]?.focus()
  }

  // Concatena as caixas no campo escondido e auto-submete quando completo.
  sync() {
    const code = this.boxTargets.map((box) => box.value).join("")
    this.hiddenTarget.value = code

    if (code.length === this.boxTargets.length) {
      this.element.requestSubmit()
    }
  }

  focusNext(box) {
    this.nextBox(box)?.focus()
  }

  focusFirstEmpty() {
    const empty = this.boxTargets.find((box) => box.value === "")
    ;(empty || this.boxTargets[0])?.focus()
  }

  nextBox(box) {
    return this.boxTargets[this.boxTargets.indexOf(box) + 1]
  }

  previousBox(box) {
    return this.boxTargets[this.boxTargets.indexOf(box) - 1]
  }
}
