import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hint"]
  static values = { delay: { type: Number, default: 90000 } }

  connect() {
    this.timeout = setTimeout(() => this.reveal(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  reveal() {
    if (this.hasHintTarget) {
      this.hintTarget.hidden = false
    }
  }
}
