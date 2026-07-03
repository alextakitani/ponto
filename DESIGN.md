# Design

> Sistema visual do Ponto, capturado do código real (`app/assets/stylesheets/`).
> Direção: **moderna, minimal densa, estilo Linear** (Q63). Base neutra, UM acento
> índigo, hierarquia por tipografia/peso/espaço, chrome quieto. **Claro + dark
> automático** via `prefers-color-scheme`, sem toggle (Q64). Zero-build: custom
> properties, sem Tailwind. A fonte da verdade dos valores é `tokens.css` — este
> documento descreve o sistema; onde divergir, o código vence.

## Theme

Dois temas, um só conjunto de tokens semânticos. O tema claro é a base
quase-branca; o escuro é quase-preto, ativado por `@media (prefers-color-scheme:
dark)` reatribuindo os mesmos tokens — **sem toggle, sem classe no `<html>`,
nenhum estado a persistir**. Todo componente lê tokens semânticos
(`--color-surface`, `--color-text`, `--color-accent`), nunca hex cru, então ambos
os temas saem "de graça".

Cena física: uma pessoa técnica na frente do próprio computador, luz de escritório
ou quarto à noite, focada em marcar horas. O dark não é decorativo — é a metade da
população que trabalha no escuro. Contraste **AA garantido nos dois temas**.

## Color

Estratégia: **restrained** — neutros tingidos + um acento contido (índigo), bem
abaixo de 10% da superfície. A cor "de personalidade" não é do app: é dos
**projetos** (bolinha/gráfico), definida por usuário. O app fica quieto pra cor do
projeto ter espaço.

### Tokens (claro → escuro)

| Token | Claro | Escuro | Papel |
|---|---|---|---|
| `--color-surface` | `#ffffff` | `#16181d` | Fundo base |
| `--color-surface-sunken` | `#f6f7f9` | `#0f1115` | Fundo recuado (sidebar, listras, chips) |
| `--color-surface-raised` | `#ffffff` | `#1d2027` | Painéis/menus elevados |
| `--color-text` | `#16181d` | `#e7e9ee` | Texto principal (~15:1 / ~13:1) |
| `--color-text-subtle` | `#5c626e` | `#9aa0ac` | Secundário (~5.6:1 / ~5.4:1, AA) |
| `--color-border` | `#e3e5e9` | `#2a2e37` | Divisórias sutis |
| `--color-border-strong` | `#c7cad1` | `#3c414d` | Hover/foco de campo |
| `--color-accent` | `#4f46e5` | `#8b8cf0` | Índigo — o único acento (AA) |
| `--color-accent-hover` | `#4338ca` | `#a1a2f4` | Hover do acento |
| `--color-on-accent` | `#ffffff` | `#16181d` | Texto sobre o acento |
| `--color-danger` | `#c22b2b` | `#f0716f` | Erro/destrutivo (AA) |
| `--color-on-danger` | `#ffffff` | `#16181d` | Texto sobre danger |

### Regras de cor

- **UM acento.** O índigo marca só: estado ativo (item de nav atual, timer
  rodando, campo em foco) e ação primária (`.btn` sólido). Nunca decorativo.
- **`color-mix` para tons derivados**, não novos tokens: fundos de hover
  (`color-mix(border 45%, transparent)`), item de nav atual (`accent 12%`), linha
  em edição (`accent 4%`), gradiente sutil da barra do timer (`accent 10%`).
- **Danger** só em erro real e ação destrutiva (Arquivar/Deletar/flash alert).
- **Foco:** `--focus-ring` = anel de acento translúcido (35–40% alpha), somado ao
  `border-color: accent` no campo.
- Cor **nunca é o único sinal** (daltonismo): timer rodando usa acento + peso; a
  bolinha do projeto sempre acompanha o nome.

## Typography

**Inter variable self-hosted** (`InterVariable.woff2`, `font-weight: 100 900`,
`font-display: swap`), servida via Propshaft. Fallback:
`system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`. Uma família só, em
poucos pesos — contraste por peso/tamanho, não por segunda fonte.

### Escala (curta e densa)

| Token | Tamanho | Uso |
|---|---|---|
| `--text-xs` | 12px | Legendas, metadados, labels de tabela (uppercase), badges |
| `--text-sm` | 13px | Texto denso, labels de form, itens de nav |
| `--text-base` | 14px | Corpo padrão, inputs, botões |
| `--text-lg` | 16px | Destaques, `h3`, marca |
| `--text-xl` | 20px | `h2`, títulos de seção |
| `--text-2xl` | 28px | `h1`, título de página |

- Pesos: `400 / 500 / 600` (normal / medium / semibold). Sem 700+.
- `line-height` base `1.5`; títulos apertam (`h1` 1.25, `h2` 1.3) com
  `letter-spacing: -0.01em` no `h1`.
- **`tabular-nums`** obrigatório em toda coluna numérica (durações, valores,
  cronômetro) — classe `.tabular-nums` (Q70). Alinhamento de dígitos é precisão.
- Labels de tabela e "eyebrows" de campo: `--text-xs`, uppercase,
  `letter-spacing: 0.03–0.04em`, cor subtle. Único uso de uppercase-tracked no
  sistema — funcional (cabeçalho de coluna), nunca eyebrow decorativo por seção.

## Spacing & Layout

Escala base 4px, curta: `--space-1..8` = 4 / 8 / 12 / 16 / 24 / 32 / 48px. Densidade
vem do **espaço e do ritmo**, não de cards.

- **Raio:** `--radius` 6px (painéis, botões, inputs), `--radius-sm` 4px (chips,
  foco, badges). Discreto.
- **Shell autenticado** (`.app`): grid `15rem 1fr` — sidebar fixa + conteúdo.
  Abaixo de `48rem` (~768px) a sidebar some e vira **bottom tab bar** fixa (mobile
  PWA). Conteúdo cap em `max-width: 64rem`.
- **Barra do timer** (`.shell-timerbar` / `.timer-bar`): topo da área principal em
  toda tela; gradiente índigo sutil a 135° a marca como assinatura. Grid de campos
  que colapsa pra 1 coluna no mobile.
- **1D → Flexbox, 2D → Grid.** Listas e toolbars em flex; tracker/tabelas/forms de
  domínio em grid. Grids de form colapsam pra `1fr` no breakpoint mobile.
- **Cards são exceção.** Só a `.card` (telas simples: auth) e painéis realmente
  elevados (menu `<details>`, form manual). Listas de dados são **`.data-table`
  densa sem card por linha** e linhas do tracker separadas por `border-bottom` —
  nunca card por item.
- **z-index semântico e baixo:** menu de linha `5`, bottom tab bar `10`. Sem 999.

## Components

Componentes genéricos vivem em `catalog.css` / `forms.css`; o específico de cada
tela mora no CSS da tela (`tracker.css`, `projects.css`, `reports.css`, `admin.css`,
`landing.css`).

- **Botões** (`forms.css`): `.btn` = acento sólido (primária); `submit` herda o
  visual do `.btn` por padrão. `.btn.btn--quiet` = neutro com borda; `.btn.btn--danger`
  = destrutivo; `.btn.btn--sm` = inline denso. *(Modificadores usam classe dobrada
  de propósito — vencem o seletor base `button[type=submit]` sem `!important`.)*
- **Inputs/select/textarea:** largura total, borda sutil, `appearance: none`, foco
  = borda acento + `--focus-ring`. Seta do select é SVG inline em data-URI (tingido
  pelo subtle; duplicado no dark). Transições de 0.12s em `border-color`/`box-shadow`.
- **Shell nav** (`shell.css`): item denso com ícone+label; atual = acento 12% de
  fundo + texto acento; "em breve" = desabilitado apagado; footer empurrado
  (Preferências/Admin/Sair). Mobile: tab bar + menu "Mais" via `<details>`.
- **Data-table** (`catalog.css`): densa, `border-bottom` por linha, header
  uppercase-subtle, coluna `.data-table__num` à direita, `.data-table__actions`
  encolhida com menu ⋮.
- **Menu ⋮ por linha** (`.row-menu`): `<details>` **zero-JS**, painel absoluto
  elevado com sombra suave. Mesmo padrão no admin, catálogo e ações de entry.
- **Empty state** (`.empty-state`): convidativo — ícone grande discreto (Lucide,
  `icon--lg`), `h2`, texto, ação. Alinhado à esquerda, não centralizado.
- **Formulários de domínio** (`.form-stack`/`.form-field`/`.form-row`): coluna
  cap em 32rem, `.form-hint` (dica curta subtle), `.form-errors` (bloco danger
  tingido), `.form-actions`.
- **Ícones:** Lucide vendorizado (Q80), helper `icon`, inline com `currentColor`,
  **sempre com label** (Q63). Tamanhos `.icon--sm` 14px / base 16px / `.icon--lg`
  40px.
- **Flash:** faixa fina no topo — `notice` neutro (surface-sunken), `alert` em
  danger sólido.
- **Badges:** `.tag-badge` (ex.: "arquivado") e `.shell-badge` ("em breve") — chips
  quietos, xs, subtle.

## Motion

Mínima e funcional. Transições curtas (0.12s ease) em hover/foco de campos e
botões. Sem bounce, sem elastic, sem reveal-on-scroll. **`prefers-reduced-motion:
reduce`** honrado globalmente em `base.css` (animações/transições ~instantâneas,
`scroll-behavior: auto`). Toda animação nova precisa de alternativa reduzida.

## Charts / Data-viz

Gráficos do relatório = **SVG server-rendered** em partial ERB, **zero JS** (Q71).
Cor dos gráficos = a cor de cada projeto (não o acento do app). Sem biblioteca de
charting no runtime (importmap, sem Node).

## Non-negotiables

- **Zero-build / zero-Node no runtime:** custom properties, sem Tailwind; SVG
  server-rendered; Hotwire (Turbo + Stimulus) em vez de JS avulso. Sem `<script>`
  inline em layouts.
- **Sempre tokens semânticos**, nunca hex cru em componente — é o que faz o dark
  automático funcionar.
- **Um acento.** Adicionar uma segunda cor de UI é sair da direção.
- **Densidade por espaço, não por chrome.** Sem card por linha, sem sombra/borda
  gratuita, sem side-stripe, sem gradient-text, sem glassmorphism, sem hero-metric.
- **`tabular-nums`** em toda coluna numérica.
- Contraste **AA** nos dois temas; texto subtle não desce de ~5.4:1.
