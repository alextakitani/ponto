import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: { type: String, default: "notice" },
    duration: Number
  }

  connect() {
    this.dismissed = false
    this.timeout = setTimeout(() => this.dismiss(), this.displayDuration)
  }

  disconnect() {
    clearTimeout(this.timeout)
    clearTimeout(this.removeTimeout)
  }

  dismiss() {
    if (!this.dismissed) {
      this.dismissed = true
      clearTimeout(this.timeout)
      this.element.classList.add("toast--leaving")

      this.element.addEventListener("animationend", () => this.remove(), { once: true })
      this.removeTimeout = setTimeout(() => this.remove(), 180)
    }
  }

  remove() {
    this.element.remove()
  }

  get displayDuration() {
    if (this.hasDurationValue) {
      return this.durationValue
    } else if (this.typeValue === "alert") {
      return 6000
    } else {
      return 4000
    }
  }
}
