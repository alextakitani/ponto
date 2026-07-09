import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "label", "details", "swatch"]

  connect() {
    this.syncFromElement()
  }

  choose(event) {
    const { id, name, color } = event.params
    this.inputTarget.value = id
    this.labelTarget.textContent = name
    this.setColor(color)
    this.markSelected(event.currentTarget)
    this.detailsTarget.open = false
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  syncFromElement() {
    this.setColor(this.element.style.getPropertyValue("--timer-project-color").trim())
  }

  setColor(color) {
    if (color) {
      this.element.style.setProperty("--timer-project-color", color)
      this.element.classList.remove("timer-bar__select--empty")
    } else {
      this.element.style.removeProperty("--timer-project-color")
      this.element.classList.add("timer-bar__select--empty")
    }
  }

  markSelected(selectedOption) {
    this.element.querySelectorAll(".timer-project-picker__option--selected").forEach((option) => {
      option.classList.remove("timer-project-picker__option--selected")
    })
    selectedOption.classList.add("timer-project-picker__option--selected")
  }
}
