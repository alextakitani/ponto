import { Controller } from "@hotwired/stimulus"

// Dá VIDA ao mockup do herói da landing (overdrive): o cronômetro tica de verdade
// e os valores faturados contam de 0 até o total. Tudo dispara SÓ quando o mockup
// entra na viewport (IntersectionObserver, uma vez) e respeita prefers-reduced-motion
// — nesse caso os números já nascem no valor final (o SSR é o fallback estático).
export default class extends Controller {
  static targets = ["clock", "amount"]
  static values = { start: String } // "01:47:12" — base do cronômetro

  connect() {
    this.reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.reduced) return // SSR já mostra os valores finais; não anima nada.

    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          this.start()
          this.observer.disconnect()
        }
      },
      { threshold: 0.4 }
    )
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
    if (this.raf) cancelAnimationFrame(this.raf)
    if (this.clockRaf) cancelAnimationFrame(this.clockRaf)
  }

  start() {
    this.tickClock()
    this.countAmounts()
  }

  // ── Cronômetro: avança a partir do valor base, em tempo real. ──────────────
  tickClock() {
    if (!this.hasClockTarget) return

    const base = this.parseHms(this.startValue || this.clockTarget.textContent)
    const t0 = performance.now()

    const render = (now) => {
      const elapsed = Math.floor((now - t0) / 1000)
      this.clockTarget.textContent = this.formatHms(base + elapsed)
      this.clockRaf = requestAnimationFrame(render)
    }
    this.clockRaf = requestAnimationFrame(render)
  }

  // ── Count-up dos valores faturados: 0 → total, com ease-out. ───────────────
  countAmounts() {
    this.amountTargets.forEach((el) => this.countOne(el))
  }

  countOne(el) {
    // O texto final é a fonte da verdade (ex.: "R$ 260,00"). Guardamos o prefixo
    // (símbolo da moeda) e o alvo numérico, e animamos só o número — a formatação
    // pt-BR (milhar/decimal) é reconstruída a cada frame pra bater com o SSR.
    const finalText = el.dataset.lpLiveFinal || el.textContent
    el.dataset.lpLiveFinal = finalText

    const match = finalText.match(/^(\D*)([\d.,]+)(.*)$/)
    if (!match) return
    const [, prefix, numberText, suffix] = match

    const target = this.parseBrl(numberText)
    const duration = 900
    const t0 = performance.now()

    const render = (now) => {
      const p = Math.min((now - t0) / duration, 1)
      const eased = 1 - Math.pow(1 - p, 3) // ease-out-cubic
      const value = target * eased
      el.textContent = `${prefix}${this.formatBrl(value)}${suffix}`
      if (p < 1) {
        this.raf = requestAnimationFrame(render)
      } else {
        el.textContent = finalText // trava no texto exato do SSR
      }
    }
    this.raf = requestAnimationFrame(render)
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  parseHms(text) {
    const parts = (text || "").trim().split(":").map((n) => parseInt(n, 10) || 0)
    while (parts.length < 3) parts.unshift(0)
    const [h, m, s] = parts
    return h * 3600 + m * 60 + s
  }

  formatHms(total) {
    const h = Math.floor(total / 3600)
    const m = Math.floor((total % 3600) / 60)
    const s = total % 60
    return [h, m, s].map((v) => String(v).padStart(2, "0")).join(":")
  }

  // "1.234,56" (pt-BR) → 1234.56
  parseBrl(text) {
    return parseFloat(text.replace(/\./g, "").replace(",", ".")) || 0
  }

  // 1234.56 → "1.234,56" (pt-BR)
  formatBrl(value) {
    return value.toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }
}
