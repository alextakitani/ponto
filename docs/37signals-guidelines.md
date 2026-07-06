# Diretrizes principais (estilo 37signals)

Diretrizes arquiteturais destiladas do
[unofficial 37signals coding style guide](https://github.com/mariochavez/unofficial-37signals-coding-style-guide)
(análise da base Fizzy). **Complementa o `STYLE.md`** (que cobre micro-estilo:
returns condicionais, ordenação de métodos, bang, visibilidade). Aqui ficam as
decisões de ARQUITETURA. Onde este guia e o `STYLE.md` se sobrepõem, valem juntos.

Cada item marca se o Ponto **já está conforme (✓)**, **diverge de propósito (⚠️)**
ou é **um alvo a manter (→)**.

## Filosofia

- **Vanilla Rails é suficiente.** Maximize o framework antes de adicionar gem;
  construa você mesmo antes de puxar dependência externa. ✓ (importmap, sem Node;
  money-rails/pagy/caxlsx são as poucas gems, cada uma justificada no grilling.)
- **Rich domain models, não service objects.** Controller fino orquestra; a lógica
  mora no model. Sem camada de service por padrão. ✓ (ver `STYLE.md` "Controller and
  model interactions".)
- **Resource-based, CRUD-oriented.** Ação que não mapeia num verbo CRUD vira um novo
  resource, não custom action. ✓ (timer `start`/`stop` → `resource :timer`; split →
  `time_entries/:id/split`; arquivar → sub-resource `archival`; onboarding skip →
  `resource :onboarding_skip`.)

## Models

- **Records-as-state, não boolean/enum pra estado com história.** Em vez de `closed:
  boolean`, um registro/timestamp separado dá QUANDO e QUEM, e escopa com
  `joins`/`where.missing`. ✓ **parcial**: usamos timestamps-como-estado onde o
  histórico importa — `archived_at` (soft delete, concern `Archivable`), `ended_at IS
  NULL` (timer rodando, sem coluna `running`). Onde o estado é um escalar sem história
  (permission `read|write`, status do import, theme), enum-string é aceito e idiomático.
- **Concerns para comportamento horizontal**, 50–150 linhas, cada um coeso e nomeado
  pela CAPACIDADE que provê (`Archivable`, `Authentication`, `MonetizableRate`), com
  suas próprias associações/scopes/métodos. Não crie concern só pra reduzir tamanho de
  arquivo. ✓
- **POROs são model-adjacent, não controller-adjacent.** Use para lógica de domínio /
  apresentação sob o namespace de um model (`Report`, `Report::Export`,
  `Clockify::Import`, `Report::Period`), NÃO como service cross-cutting. ✓
- **Current para contexto de request/tenancy.** `Current.user`/`Current.session` em
  vez de threat o contexto por parâmetro; o job usa `import.user` explícito (o
  tenant sobrevive ao async). ✓ (isolamento por `user_id`, Q23.)
- **Validações mínimas no model.** Só o essencial declarativo; fluxos multi-etapa
  validam em classes contextuais. ✓
- **Callbacks com parcimônia** — só setup/cleanup, nunca regra de negócio. ✓ (ex.:
  `before_validation :snapshot_project_rate` é normalização de dado, não fluxo.)
- **Scopes com nome de negócio, não de SQL.** `active`/`archived` em vez de
  `where_null_archived_at`. ✓
- **Bang nos controllers** (`create!`/`update!`) — deixe a falha propagar. ✓

## Controllers

- **Fino, orquestra chamando o model.** AR direto (`@card.comments.create!(...)`) ou
  API de intenção do model (`@card.gild`). Sem lógica de negócio no controller. ✓
- **Autorização = controller CHECA, model DEFINE.** `before_action` checa; o predicado
  vive na policy/model. ✓ (Action Policy: `authorize!` no controller, `relation_scope`
  + predicados na policy.)
- **ApplicationController enxuto** — compõe via `include` de concerns
  (`Authentication`, `OnboardingGate`, `SetLocale`…), sem lógica direta. ✓
- **before_action no `included` do concern**; `around_action` pra envolver request
  (locale, timezone); `after_action` pra resposta (headers). ✓

## Hotwire / Stimulus

- **Frames para navegação escopada** (form section que não pode resetar, conteúdo
  isolado, lazy-load); **Streams para múltiplos updates**. ✓ (frame `export_options`
  do idioma do export; broadcast do import.)
- **Progressive enhancement:** filtros/navegação como `<a>`/form nativos, não botão
  movido a JS — o browser dá right-click, cmd+click de graça. ✓ (setas do período,
  presets, seletores como link/form.)
- **Stimulus pequeno, uma responsabilidade.** Values/Targets API sobre
  `getAttribute()`; **sempre** limpar em `disconnect()` (timers, listeners);
  descritores `data-action` declarativos em vez de `addEventListener` manual. ✓
  (`stopwatch`, `theme`, `settings_select`, `clockify_import_watchdog` — todos limpam
  ou são declarativos.)
- **Sem `<script>` inline em layout** — sempre Stimulus controller. ✓ (regra da
  CLAUDE.md.)

## Testes

- **Minitest**, integração sobre unidade isolada; teste NOSSA lógica, não o framework
  (relacionamentos AR, validações declarativas e presença de texto na tela NÃO se
  testam). ✓ (regra da CLAUDE.md "Testes".)
- **Testes shipam JUNTO da feature, no MESMO commit.** Fix de segurança sempre com
  teste de regressão. ✓ (fluxo desta base: gate verde por fatia.)
- `assert_difference`/`assert_no_difference` pra mudança de estado;
  `assert_redirected_to` pra navegação; `assert_response :forbidden` pra autorização;
  `travel_to` pra tempo; `perform_enqueued_jobs` pra jobs. ✓
- ⚠️ **DIVERGÊNCIA CONSCIENTE — fixtures.** O guia 37signals prega **fixtures** sobre
  factories. O Ponto usa **nem-fixtures-nem-factories**: cada teste cria só o que
  precisa via helper `create_user` (ver `test/test_helper.rb` e a seção "Testes" da
  CLAUDE.md). Motivo: a suíte fica enxuta e cada teste é auto-explicativo sem um
  arquivo de fixtures global a manter numa base single-context pequena. **É uma escolha
  deliberada; não "corrigir" pra fixtures.**

## Onde divergimos de propósito (resumo)

- **Fixtures → helper `create_user`** (acima).
- **`prefers-reduced-motion` ignorado no app inteiro** (decisão do dono, contra WCAG
  2.3.3, documentada no base.css) — não é do guia, mas é uma divergência ativa de
  "acessibilidade" que o guia valoriza. Consciente.
- Enum-string para estado escalar sem história (o guia prefere records-as-state, mas
  só onde há história — nossos escalares sem história ficam em enum, idiomático).
