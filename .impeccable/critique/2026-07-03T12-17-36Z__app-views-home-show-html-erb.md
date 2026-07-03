---
target: tracker (home/show)
total_score: 30
p0_count: 0
p1_count: 2
timestamp: 2026-07-03T12-17-36Z
slug: app-views-home-show-html-erb
---
# Critique — Tracker (re-run pós-fixes)

**Method: dual-agent** (A: design review · B: detector evidence) — isolados, paralelos, sintetizados.
**Target:** `home/show` + partials + timer bar + as duas superfícies novas (⌘K palette, paginação Pagy).

## Design Health Score

| # | Heurística | Antes | Agora | Δ | Nota |
|---|---|---|---|---|---|
| 1 | Visibility of Status | 3 | 3 | – | Stop ainda silencioso; total do dia congela após paginar (novo). |
| 2 | Match Real World | 3 | 3 | – | "Retomar"/"Recentes" ok. |
| 3 | User Control | 2 | 3 | +1 | ⌘K dá saída/navegação; Esc no split ainda é trap. |
| 4 | Consistency | 3 | 3 | – | Palette usa os tokens; item selecionado = accent 10%. |
| 5 | Error Prevention | 2 | 3 | +1 | 409 tratado no restart e na palette; last_date com rescue. |
| 6 | Recognition | 3 | 4 | +1 | Hoje/Ontem + palette torna ações descobríveis. |
| 7 | Flexibility | 1 | 3 | +2 | ⌘K + Retomar + `/` — o maior salto. Falta só o `/` cross-page e bulk. |
| 8 | Aesthetic/Minimal | 3 | 3 | – | Trigger de busca fixo no desktop é ruído; subtítulo já cortado. |
| 9 | Error Recovery | 2 | 2 | – | Erro de edição inline ainda pode render off-screen. |
| 10 | Help/Docs | 2 | 3 | +1 | Palette com descrições (<small>) é auto-documentante. |
| **Total** | | **24** | **30** | **+6** | Good — base sólida, alguns bugs de borda das features novas. |

## Anti-Patterns Verdict

Não parece AI-gerado, e melhorou. Detector: 0 findings nos 12 ERB. Régua de z-index respeitada (o <dialog> usa top-layer nativo, não precisa de z-index; o 20 é só do botão trigger). A palette é idiomática de verdade — <dialog> real com showModal(), ::backdrop, filtro por label com sinônimos PT+EN, reduced-motion honrado, tokens em tudo. Um usuário fluente em Raycast/Linear confiaria nela. Falsos-positivos descartados: os rgba(0,0,0,.12) de sombra (não há token de sombra — observação DRY, não bug), o hex em data-URI, os 4 !important do reduced-motion.

## What's Working
1. Flexibility saltou de 1→3. A palette ⌘K + "Retomar última" + `/` transformaram a heurística mais fraca — o P1 mais impactante do critique anterior, resolvido.
2. A palette é craft de verdade. <dialog> nativo (foco-trap grátis), label escondido mas presente, role="status" no vazio, item selecionado com accent contido. Zero-build, zero-lib.
3. Os fixes de mobile pegaram. Detector confirma: barra sticky top:0 z-index:4, tab bar min-height:3rem, .btn/.btn--sm 2.75rem. Todos ≥44px.

## Priority Issues

**[P1] Total do dia congela ao "Carregar mais" — número errado.** (A achou, verificado à mão)
Na borda de dia, turbo_stream.append "day-#{date}-entries" anexa só as linhas; o .tracker-day__total no header não é alvejado (nem tem id) → um dia com 60 entries mostra o total de só 50 após paginar. Viola o princípio "o número está certo". Fix: dar id="day-#{date}-total" ao span e, no stream de borda, turbo_stream.update o total com o valor recalculado. Regressão da fatia Pagy.

**[P1] Trigger de busca (40px) e barra sticky se sobrepõem no mobile.** (A + B)
.shell-command__trigger é fixed; top: var(--space-3); right — mesmo canto que a barra sticky do timer. O botão é 40px, abaixo dos 44px (o @media só reposiciona, não redimensiona) e fica na zona pior pro polegar. Fix: no mobile, mover o trigger pra dentro da barra/tab bar, ou padding-right na timerbar + min-height:2.75rem;width:2.75rem no trigger. → /impeccable adapt

**[P2] Esc no split aninhado fecha o menu ⋮ inteiro.** (A)
O menu_controller do .row-menu externo captura Escape antes do <details> interno do split → keyboard trap. Fix: o handler checar <details open> aninhado e deixá-lo fechar primeiro (stopPropagation no interno). → /impeccable harden

**[P2] aria-selected ausente na navegação por setas da palette.** (A + B)
Setas mudam a classe --selected visual, mas nenhum aria-selected/aria-activedescendant — leitor de tela não anuncia o item ativo. Fix: aria-activedescendant no input + role="option"/aria-selected nos itens (padrão combobox). → /impeccable harden

**[P3] Filtro da palette: "retomar" casa todas as Recentes.** (A)
Todo item de Recentes tem "retomar recentes" no label. Fix: tirar a palavra genérica ou pesar prefix-match. → /impeccable clarify

## Persona Red Flags
- Alex: ⌘K + Retomar o satisfazem muito melhor (Flexibility 1→3). Resta: `/` só funciona em /home (não em Reports/Projects), sem bulk, palette carrega via turbo_frame src: (request extra no 1º ⌘K).
- Sam: <dialog>+showModal()+label escondido+role="status" = base correta. Gaps: aria-selected e o Esc-trap do split.
- Casey: sticky bar + 44px landaram ✓. Mas o trigger da palette é 40px, canto superior direito (pior zona de polegar), ícone de lupa que sugere "buscar na página".

## Minor Observations
- .tracker-load-more div renderiza vazio no 1º load sem mais páginas — elemento órfão.
- onTrackerPage() com /home hardcoded (dívida P3) — o `/` quebra silencioso se a rota mudar.
- Palette lazy via turbo-frame: considerar inline pro ⌘K abrir instantâneo.

## Questions to Consider
1. "Retomar última" (barra) e "Recentes" (palette) se sobrepõem — manter os dois ou a barra focar só em "iniciar novo"?
2. Sinal de billable/rate na linha ainda ausente — o export é o entregável principal (aberto do critique 1).
3. O trigger de busca fixo no desktop precisa existir? Linear-style, ⌘K não tem botão visível no desktop.
