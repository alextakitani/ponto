import { Controller } from "@hotwired/stimulus"

// O morph do Turbo 8 PULA elementos data-turbo-permanent (turbo-rails:
// shouldRefreshFrameWithMorphing exclui closest([data-turbo-permanent])), então a
// barra do timer não atualiza sozinha num page refresh. Recarregamos o frame à mão
// quando a página morfa — mantendo o permanent (cronômetro segue entre telas).
export default class extends Controller {
  connect() {
    this.reload = () => {
      // Não recarrega enquanto o usuário digita DENTRO da barra (ex.: descrição no
      // form ocioso) — o reload apagaria o que ele escreveu. O broadcast reflete numa
      // próxima interação; a barra dele já está na frente do que veio pelo cable.
      if (this.element.contains(document.activeElement)) return

      // View Transition dá um cross-fade suave na troca rodando↔ocioso em vez do
      // "pulo" da substituição seca do frame. O reload() resolve quando o frame
      // terminou de renderizar, então a transição captura o estado FINAL. Fallback:
      // reload direto onde a API não existe.
      if (document.startViewTransition) {
        document.startViewTransition(() => this.element.reload())
      } else {
        this.element.reload()
      }
    }
    document.addEventListener("turbo:morph", this.reload)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.reload)
  }
}
