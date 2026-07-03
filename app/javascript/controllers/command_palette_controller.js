import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "input", "item", "group", "status", "trigger"]

  connect() {
    this.selectedIndex = 0
    this.previouslyFocused = null
  }

  dialogTargetConnected(element) {
    this.closeFromDialog = this.closeFromDialog?.bind(this) || this.close.bind(this)
    element.addEventListener("close", this.closeFromDialog)
  }

  dialogTargetDisconnected(element) {
    if (this.closeFromDialog) {
      element.removeEventListener("close", this.closeFromDialog)
    }
  }

  handleGlobalKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open(event)
      return
    }

    if (event.key === "/" && this.onTrackerPage() && !this.dialogOpen() && !this.typingInField(event.target)) {
      const description = document.querySelector(".timer-bar--idle input[name='timer[description]']")
      if (description) {
        event.preventDefault()
        description.focus()
      }
    }
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget) return

    this.previouslyFocused = document.activeElement
    if (!this.dialogTarget.open) {
      this.dialogTarget.showModal()
    }
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.inputTarget.value = ""
    this.filter()
    this.inputTarget.focus()
  }

  close() {
    this.clearSelection()
    if (this.hasInputTarget) this.inputTarget.value = ""

    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("aria-expanded", "false")
      this.inputTarget.removeAttribute("aria-activedescendant")
    }

    const focusTarget = this.previouslyFocused?.isConnected ? this.previouslyFocused : this.hasTriggerTarget ? this.triggerTarget : null
    focusTarget?.focus()
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()

    this.itemTargets.forEach((item) => {
      const label = item.dataset.commandPaletteLabel || item.textContent
      item.hidden = query.length > 0 && !label.toLowerCase().includes(query)
    })

    this.groupTargets.forEach((group) => {
      group.hidden = group.querySelectorAll("[data-command-palette-target~='item']:not([hidden])").length === 0
    })

    this.selectedIndex = 0
    this.applySelection()
  }

  handleListKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.moveSelection(1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.moveSelection(-1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.activateSelected()
    }
  }

  focusTimer(event) {
    event.preventDefault()
    this.close()
    document.querySelector(".timer-bar--idle input[name='timer[description]']")?.focus()
  }

  moveSelection(delta) {
    const items = this.visibleItems()
    if (items.length === 0) return

    this.selectedIndex = (this.selectedIndex + delta + items.length) % items.length
    this.applySelection()
  }

  activateSelected() {
    const item = this.visibleItems()[this.selectedIndex]
    if (!item) return

    this.close()
    item.click()
  }

  applySelection() {
    const items = this.visibleItems()
    this.clearSelection()

    if (items.length === 0) {
      this.statusTarget.textContent = "Nenhuma ação encontrada."
      this.inputTarget.removeAttribute("aria-activedescendant")
      return
    }

    this.selectedIndex = Math.min(this.selectedIndex, items.length - 1)
    const selected = items[this.selectedIndex]
    selected.classList.add("command-palette__item--selected")
    selected.setAttribute("aria-selected", "true")
    this.inputTarget.setAttribute("aria-activedescendant", selected.id)
    selected.scrollIntoView({ block: "nearest" })
    this.statusTarget.textContent = ""
  }

  clearSelection() {
    this.itemTargets.forEach((item) => {
      item.classList.remove("command-palette__item--selected")
      item.setAttribute("aria-selected", "false")
    })
  }

  visibleItems() {
    return this.itemTargets.filter((item) => !item.hidden && !item.closest("[hidden]"))
  }

  dialogOpen() {
    return this.hasDialogTarget && this.dialogTarget.open
  }

  typingInField(element) {
    return element.matches("input, textarea, select, [contenteditable='true']")
  }

  onTrackerPage() {
    return window.location.pathname === "/home"
  }
}
