import { Controller } from "@hotwired/stimulus"

// Cria tag inline no form: a tag nova entra NA LISTA de opções junto das
// existentes, já MARCADA (checkbox name=new_tag_names[]) — desmarcar cancela a
// criação (checkbox desmarcado não submete). Fallback sem JS: o input de texto já
// tem name new_tag_names[], então um valor digitado ainda envia sozinho no submit.
export default class extends Controller {
  static targets = ["input", "options"]
  static values = { scope: { type: String, default: "time_entry" } }

  add(event) {
    event.preventDefault()
    const name = this.inputTarget.value.trim()
    if (name.length === 0) return

    // Já existe opção com o mesmo nome (case-insensitive)? Só marca ela.
    const existing = this.optionTargetsByText(name)
    if (existing) {
      existing.querySelector("input[type=checkbox]").checked = true
    } else {
      this.optionsTarget.appendChild(this.buildOption(name))
    }

    this.inputTarget.value = ""
    this.inputTarget.focus()

    // Dispara change no elemento raiz para o dirty-form perceber que o form mudou.
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  buildOption(name) {
    const label = document.createElement("label")
    label.className = "tags-field__option"

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.name = `${this.scopeValue}[new_tag_names][]`
    checkbox.value = name
    checkbox.checked = true

    const text = document.createElement("span")
    text.textContent = name

    label.append(checkbox, text)
    return label
  }

  optionTargetsByText(name) {
    const wanted = name.toLowerCase()
    return Array.from(this.optionsTarget.querySelectorAll("label")).find(
      (label) => label.textContent.trim().toLowerCase() === wanted
    )
  }
}
