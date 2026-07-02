import { Controller } from "@hotwired/stimulus"

// Placeholder de rate herdada AO VIVO no form do Project (Q45). Quando o usuário troca
// o cliente no select, o texto auxiliar reflete a rate DAQUELE cliente sem recarregar
// nem fazer fetch — o mapa client_id -> rate formatada vem embutido em data-value.
// O input de rate vazio SIGNIFICA "herda"; o Stimulus só ajusta o texto explicativo.
//
// As três frases têm que casar com o helper `project_rate_hint` (server-render inicial):
// sem cliente · cliente sem taxa · cliente com taxa. Mantê-las em sincronia é intencional.
export default class extends Controller {
  static targets = ["client", "input", "hint"]
  static values = { rates: Object }

  clientChanged() {
    this.hintTarget.textContent = this.hintFor(this.clientTarget.value)
  }

  // Monta o texto do placeholder pro cliente selecionado. `id` vazio = "Sem cliente".
  // `ratesValue` mapeia id (string) -> rate formatada ("R$ 150,00") ou null (sem taxa).
  hintFor(id) {
    if (!id) {
      return "Sem cliente → defina um valor ou o projeto fica sem taxa."
    }

    const rate = this.ratesValue[id]
    if (rate) {
      return `Herdando do cliente: ${rate} — preencha para sobrescrever.`
    } else {
      return "Este cliente não tem taxa → defina um valor ou o projeto fica sem taxa."
    }
  }
}
