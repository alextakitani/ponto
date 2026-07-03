import { Controller } from "@hotwired/stimulus"

// Acumula novas tags inline antes do submit mantendo fallback sem JS: o input já tem
// name `time_entry[new_tag_names][]`, então um valor simples ainda envia sozinho.
export default class extends Controller {
  static targets = ["input", "pending"]

  add(event) {
    event.preventDefault()
    const name = this.inputTarget.value.trim()
    if (name.length === 0) return

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = "time_entry[new_tag_names][]"
    hidden.value = name

    const chip = document.createElement("button")
    chip.type = "button"
    chip.className = "tag-badge"
    chip.textContent = name
    chip.appendChild(hidden)
    chip.addEventListener("click", () => chip.remove())

    this.pendingTarget.appendChild(chip)
    this.inputTarget.value = ""
  }
}
