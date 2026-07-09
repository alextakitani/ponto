import { Controller } from "@hotwired/stimulus"

// Três campos LIGADOS do entry manual (Q46): início · fim · duração. Regra:
//   - Editar a DURAÇÃO ("2:30" / "2h30" / "90m" / "2h") → fim = início + duração.
//   - Editar INÍCIO ou FIM → recalcula a duração a partir dos dois.
// Tudo client-side (sem ida ao servidor); o servidor recebe SÓ início+fim reais
// (o campo de duração é auxiliar e não tem name — ver _manual_form). Anexar com
// data-controller="duration-fields". Segue o padrão dos outros controllers: handlers
// ligados em connect(), removidos em disconnect() pra não vazar quando o Turbo troca o DOM.
export default class extends Controller {
  static targets = ["start", "end", "duration"]

  connect() {
    this.onStartOrEnd = this.startOrEndChanged.bind(this)
    this.onDuration = this.durationChanged.bind(this)

    this.startTarget.addEventListener("input", this.onStartOrEnd)
    this.endTarget.addEventListener("input", this.onStartOrEnd)
    this.durationTarget.addEventListener("input", this.onDuration)
  }

  disconnect() {
    this.startTarget.removeEventListener("input", this.onStartOrEnd)
    this.endTarget.removeEventListener("input", this.onStartOrEnd)
    this.durationTarget.removeEventListener("input", this.onDuration)
  }

  // Mexeu em início OU fim: se ambos estão preenchidos, recalcula a duração exibida.
  startOrEndChanged() {
    const start = this.parseDateTime(this.startTarget.value)
    const end = this.parseDateTime(this.endTarget.value)
    if (!start || !end || end <= start) return

    const totalSeconds = Math.round((end - start) / 1000)
    this.durationTarget.value = this.formatDuration(totalSeconds)
  }

  // Mexeu na duração: se início e duração são válidos, recalcula o fim = início + duração.
  durationChanged() {
    const start = this.parseDateTime(this.startTarget.value)
    const seconds = this.parseDuration(this.durationTarget.value)
    if (!start || seconds === null) return

    const end = new Date(start.getTime() + seconds * 1000)
    this.endTarget.value = this.formatDateTimeLocal(end)
  }

  // "0:00:22" (h:mm:ss) · "2:30" (h:mm, segundos=0) · "2h30" · "2h30m" · "2h" · "90m" ·
  // "90" (minutos) · "2.5h". Retorna total em SEGUNDOS (precisão casada com o
  // datetime-local `step=1`) ou null se não der pra interpretar.
  parseDuration(raw) {
    const text = raw.trim().toLowerCase()
    if (!text) return null

    // Formato relógio "h:mm:ss".
    const hms = text.match(/^(\d+):([0-5]?\d):([0-5]?\d)$/)
    if (hms) {
      return parseInt(hms[1], 10) * 3600 + parseInt(hms[2], 10) * 60 + parseInt(hms[3], 10)
    }

    // Formato relógio "h:mm".
    const clock = text.match(/^(\d+):([0-5]?\d)$/)
    if (clock) {
      return parseInt(clock[1], 10) * 3600 + parseInt(clock[2], 10) * 60
    }

    // Formato "2h30", "2h30m", "2h", "30m", "2.5h".
    const hm = text.match(/^(?:(\d+(?:\.\d+)?)\s*h)?\s*(?:(\d+)\s*m?)?$/)
    if (hm && (hm[1] || hm[2])) {
      const hours = hm[1] ? parseFloat(hm[1]) : 0
      const mins = hm[2] ? parseInt(hm[2], 10) : 0
      const total = Math.round(hours * 3600) + mins * 60
      return total > 0 ? total : null
    }

    return null
  }

  formatDuration(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600)
    const minutes = Math.floor((totalSeconds % 3600) / 60)
    const seconds = totalSeconds % 60

    return `${hours}:${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`
  }

  // datetime-local é "YYYY-MM-DDTHH:MM:SS" no HORÁRIO LOCAL do browser (casado com
  // `step=1`); `new Date` sobre essa string já interpreta como local (sem sufixo Z).
  // Vazio/ inválido → null.
  parseDateTime(value) {
    if (!value) return null
    const date = new Date(value)
    return isNaN(date.getTime()) ? null : date
  }

  formatDateTimeLocal(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return (
      `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
      `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
    )
  }
}
