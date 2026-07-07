import { Controller } from "@hotwired/stimulus"

// Clique na barra do dia (Reports): troca o pulo seco da âncora por scroll suave +
// destaque da barra clicada e das linhas do dia na tabela Detailed. Client-side puro
// (feedback de navegação intra-página) — Frame/Stream não cobrem. Anexar no wrapper
// que contém gráfico E tabela (index.html.erb).
export default class extends Controller {
  static SELECTED_BAR = "report-bars__col--selected"
  static HIGHLIGHTED_ROW = "report-detailed__row--highlight"

  connect() {
    // Deep-link: chegando com #report-day-... na URL, o browser já posicionou —
    // só aplicamos destaque + foco, sem forçar um segundo scroll.
    const match = location.hash.match(/^#report-day-(\d{4}-\d{2}-\d{2})$/)
    if (match) this.highlight(match[1], { scroll: false })
  }

  select(event) {
    event.preventDefault()
    this.highlight(event.params.date, { scroll: true })
  }

  highlight(date, { scroll }) {
    const row = this.element.querySelector(`#report-day-${date}`)
    if (!row) return

    this.markBar(date)
    this.markRows(date)

    if (scroll) {
      row.scrollIntoView({ behavior: "smooth", block: "start" })
      // Âncora continua compartilhável, sem o pulo nativo do hash.
      history.replaceState(history.state, "", `#report-day-${date}`)
    }

    row.focus({ preventScroll: true })
  }

  markBar(date) {
    const selected = this.constructor.SELECTED_BAR
    this.element.querySelectorAll(`.${selected}`).forEach((col) => col.classList.remove(selected))
    this.element.querySelector(`[data-report-day-date-param="${date}"]`)?.classList.add(selected)
  }

  markRows(date) {
    const highlighted = this.constructor.HIGHLIGHTED_ROW
    this.element.querySelectorAll(`.${highlighted}`).forEach((tr) => tr.classList.remove(highlighted))
    this.element.querySelectorAll(`tr[data-date="${date}"]`).forEach((tr) => tr.classList.add(highlighted))
  }
}
