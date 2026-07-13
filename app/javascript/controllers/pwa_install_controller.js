import { Controller } from "@hotwired/stimulus"

// Instalação da PWA controlada por NÓS, não pela heurística do navegador.
//
// Motivo: o Chrome/Android só dispara o mini-infobar nativo depois de julgar o
// usuário "engajado" (segundos de uso, às vezes 2ª visita) e ainda com cooldown
// próprio — por isso "só pedia depois de um tempo". Aqui interceptamos
// `beforeinstallprompt` (preventDefault → o banner nativo não aparece), guardamos
// o evento e mostramos NOSSO banner na 1ª chance. Um flag em localStorage garante
// o "uma vez só": dispensou/instalou → nunca mais.
//
// iOS/Safari NÃO dispara `beforeinstallprompt` e não permite instalar por código:
// detectamos o caso e mostramos uma dica manual (Compartilhar → Adicionar à Tela
// de Início) em vez do botão de instalar.
//
// Serve DOIS lugares com o mesmo controller (targets opcionais):
//  - banner do shell (target `banner`, dispensável, some depois do flag)
//  - botão em Preferências (target `button`, habilita só quando instalável)
export default class extends Controller {
  static targets = ["banner", "button", "iosHint", "unavailable"]
  static values = { dismissKey: { type: String, default: "ponto-a2hs-dismissed" } }

  connect() {
    this.deferredPrompt = null

    // Já instalado (rodando como app) ou já dispensou → não oferece nada.
    if (this.isStandalone || this.isDismissed) {
      this.hideAll()
      return
    }

    if (this.isIos) {
      // Safari: sem evento programático. Só a dica manual faz sentido.
      this.revealIosHint()
      return
    }

    this.onBeforeInstallPrompt = this.handleBeforeInstallPrompt.bind(this)
    this.onAppInstalled = this.handleAppInstalled.bind(this)
    window.addEventListener("beforeinstallprompt", this.onBeforeInstallPrompt)
    window.addEventListener("appinstalled", this.onAppInstalled)
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.onBeforeInstallPrompt)
    window.removeEventListener("appinstalled", this.onAppInstalled)
  }

  handleBeforeInstallPrompt(event) {
    // Impede o banner nativo; a partir daqui quem dispara o prompt somos nós.
    event.preventDefault()
    this.deferredPrompt = event
    this.reveal()
  }

  handleAppInstalled() {
    // Instalou por qualquer caminho (nosso botão ou o menu do navegador):
    // marca o flag e esconde tudo pra não reoferecer.
    this.remember()
    this.hideAll()
  }

  // Ação dos botões "Instalar" (banner e Preferências).
  async install() {
    if (!this.deferredPrompt) return

    this.deferredPrompt.prompt()
    const { outcome } = await this.deferredPrompt.userChoice
    this.deferredPrompt = null

    // Aceito OU recusado: em ambos os casos não insistimos de novo (evita spam).
    // Se recusou, o botão de Preferências continua lá pra tentar quando quiser.
    if (outcome === "accepted") {
      this.remember()
    }
    this.hideBanner()
  }

  // Ação do "Agora não" no banner.
  dismiss() {
    this.remember()
    this.hideBanner()
  }

  // — helpers de estado —

  reveal() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = false
    if (this.hasButtonTarget) this.buttonTarget.hidden = false
    // Dá pra instalar → some a nota "este dispositivo não oferece instalação".
    this.hideUnavailable()
  }

  revealIosHint() {
    if (this.hasIosHintTarget) this.iosHintTarget.hidden = false
    // A dica do iOS já explica como instalar → a nota "indisponível" não cabe.
    this.hideUnavailable()
  }

  hideUnavailable() {
    if (this.hasUnavailableTarget) this.unavailableTarget.hidden = true
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = true
  }

  hideAll() {
    this.hideBanner()
    if (this.hasButtonTarget) this.buttonTarget.hidden = true
    if (this.hasIosHintTarget) this.iosHintTarget.hidden = true
    this.hideUnavailable()
  }

  remember() {
    try {
      localStorage.setItem(this.dismissKeyValue, "1")
    } catch (_e) {
      // localStorage bloqueado (modo privado/ITP): sem persistência do flag,
      // mas o banner já sumiu nesta sessão — degradação aceitável.
    }
  }

  get isDismissed() {
    try {
      return localStorage.getItem(this.dismissKeyValue) === "1"
    } catch (_e) {
      return false
    }
  }

  get isStandalone() {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      // iOS Safari usa a propriedade legada em vez do display-mode.
      window.navigator.standalone === true
    )
  }

  get isIos() {
    const ua = window.navigator.userAgent
    const isIosDevice = /iphone|ipad|ipod/i.test(ua)
    // iPad no modo desktop se disfarça de Mac; detecta pelo touch.
    const isIpadOs = /macintosh/i.test(ua) && "ontouchend" in document
    return isIosDevice || isIpadOs
  }
}
