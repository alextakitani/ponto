import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { startedAt: String }

  connect() {
    this.render = this.render.bind(this)
    this.render()
    this.interval = setInterval(this.render, 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  render() {
    const startedAt = new Date(this.startedAtValue)
    const elapsedSeconds = Math.max(Math.floor((Date.now() - startedAt.getTime()) / 1000), 0)

    this.element.textContent = this.format(elapsedSeconds)
  }

  format(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    return [hours, minutes, seconds].map((value) => String(value).padStart(2, "0")).join(":")
  }
}
