# Ponto

Time-tracker self-hosted **multi-usuário, sem colaboração/times** (cada usuário tem
sua própria bolha isolada de dados), no espírito Clockify/Toggl mas enxuto, pra rodar
no homelab e ser publicado **open source**. Rails 8 + Hotwire + SQLite.

> ⚠️ **Esta CLAUDE.md foi reconciliada (30/06/2026) com as decisões de design do
> grilling.** A fonte de verdade detalhada e o RACIONAL de cada decisão estão em
> **`docs/grilling-progress.md`** (Q1–Q24+). Onde esta CLAUDE.md e o grilling-progress
> divergirem, o grilling-progress vence (é mais novo e mais detalhado). Várias
> premissas originais mudaram: o app NÃO é mais single-user no sentido de "um registro
> de User" (ver Stack), `project_id` é nulável, a rate tem override por projeto, e há
> admin/convite/landing.

## Documentos de referência (leia antes de decidir arquitetura/UI)

- `docs/grilling-progress.md` — **decisões de design fechadas (Q1–Q24+) + racional.**
  Leia PRIMEIRO; é a fonte de verdade mais recente.
- `docs/time-tracker-decisoes.md` — racional original de arquitetura e escopo (parte
  superada pelo grilling — cruze com ele).
- `docs/time-tracker-spec.pdf` — brief funcional/UI (telas do Clockify com o que
  **MANTER / REMOVER** por tela). Pareie os dois.
- `docs/decisoes-auth-fizzy.md` — o que clonamos do `basecamp/fizzy` (auth/config),
  o que adaptamos e por quê.
- `STYLE.md` — guia de estilo (adaptado do fizzy). Siga ao escrever código novo.

Referência de implementação: **`basecamp/fizzy`** (Rails+Hotwire), clonado em
`~/Projetos/fizzy`. **Estudar padrões, não copiar** (licença O'Saasy, não-MIT).

## Stack — restrições inegociáveis

- **Rails 8.1** + **Hotwire** (Turbo + Stimulus). **Não** SPA, React, Inertia.
- **SQLite** (backup = um arquivo). Banco em UTC.
- **importmap** — sem build de JS, sem Node no runtime.
- **PWA** pra mobile (mesma UI responsiva + manifest + service worker), online-only,
  sem offline sync. Rotas `manifest`/`service-worker` já existem; faltam as views.
- **CSS**: custom properties zero-build (estilo fizzy) ou Tailwind via binário
  standalone (sem Node). Estética alvo: **retrô anos 90**.
- **Multi-usuário SEM times** (Q23): o app permite criação de contas; vários usuários
  independentes, cada um na própria bolha. **Isolamento total por `user_id`** em todas
  as tabelas de domínio — ZERO dado compartilhado entre contas. O que NÃO existe:
  **equipe, colaboração, compartilhamento, papéis colaborativos**. Onde o Clockify
  mostrar Team/Shared/Access (dimensões de equipe), **ignorar**. (O único papel é
  `User.admin`, operacional — gerencia contas/convites, NÃO vê dados alheios; ver Auth.)

## Comandos

```bash
bin/rails server                 # dev (porta 3000)
bin/rails console
bin/rails db:migrate
bin/rails test                   # Minitest — deve passar 100%
bin/brakeman -q --no-pager       # segurança — deve dar 0 warnings
bin/rubocop                      # estilo (rubocop-rails-omakase)
```

## Testes (Minitest)

**Sempre escreva testes para código novo.** Mas teste **nossa lógica, não o
framework**. A suíte deve ficar enxuta e útil.

**Testar:**
- Regras de negócio e de domínio nossas (ex.: `SignInCode.consume` uso único e
  expiração; `AccessToken#allows?` mapeando permission → método HTTP).
- Parsing/normalização nossa (ex.: `SignInCode::Code.sanitize`).
- **Fluxo de controle** dos controllers/concerns que nós escrevemos (ex.: as duas
  etapas do login, escopo do bearer) — via integration test.
- Regressões de bugs reais que encontrarmos.

**NÃO testar:**
- Relacionamentos do Active Record (`has_many`/`belongs_to`), `dependent:` etc.
- Validações declarativas (`validates ...`) — é configuração de framework.
- Se um texto/elemento aparece numa tela — não testamos a view nesse nível.
- Comportamento que é puramente Rails/gem (não é nosso).

**Como:** sem fixtures — cada teste cria só o que precisa (há helper `create_user`
em `test/test_helper.rb`). Mailer roda via `deliver_later`, então em teste use
`perform_enqueued_jobs { ... }` e leia `ActionMailer::Base.deliveries` para pegar o
código. `allow_forgery_protection` é `false` em teste (não dá pra testar CSRF por
integration; a isenção da extensão vive em `RequestForgeryProtection`).

⚠️ **Migrations já aplicadas**: editar um arquivo de migration já rodado não tem
efeito. Em dev, pra rebuildar o schema do zero: `rm storage/*.sqlite3 db/schema.rb &&
bin/rails db:create db:migrate` (o `schema.rb` é a fonte que o `db:create` carrega).

## Autenticação (implementada — ver `decisoes-auth-fizzy.md`)

Passwordless puro, **sem senha/Devise/OAuth/passkey**.

- **Magic code de 6 dígitos**: expira 15 min, uso único (consome-e-destrói).
  Guardamos só o **digest** (SHA256), nunca o código em claro.
- **Fluxo 2 etapas na mesma aba** (Turbo Stream troca o form de e-mail pelo de
  código). O e-mail "pendente" viaja num **cookie assinado**, não na URL.
- **Em dev** o código sai no header `X-Sign-In-Code` + `flash[:sign_in_code]`
  (há guarda que dá `raise` se vazar fora de dev).
- **Segurança = rate limit + expiração curta + uso único.** Sem contador de
  tentativas (teatro pro modelo de ameaça).
- **Concern de auth único** (`Authentication`): cookie de sessão (signed_id) →
  senão Bearer `AccessToken` (só em JSON, escopado por método) → senão exige login.
- **AccessToken** (extensão de Chrome): `permission` `read|write` — GET/HEAD livres,
  escrita exige `write`. Gerado no app, colado na extensão.
- **CSRF**: `RequestForgeryProtection` isenta requests JSON+Bearer (a extensão).
  Navegação de browser segue protegida.

Arquivos: `app/controllers/concerns/authentication.rb` (+ `authentication/
via_sign_in_code.rb`), `request_forgery_protection.rb`; models `User`, `Session`
(sem coluna token — usa `signed_id`), `SignInCode` (+ `sign_in_code/code.rb`),
`AccessToken`, `Current`.

### Acesso por CONVITE (a construir — Q24)

Não há signup público auto-servido. Acesso é controlado:

- **Bootstrap do admin**: no PRIMEIRO acesso, sem nenhuma conta no banco, o app cria
  o **admin geral** (primeiro user = admin). `admin` é um **boolean no `User`** (não
  roles). Papel OPERACIONAL: gerencia contas/convites/pedidos; **NÃO vê dados de
  domínio de outros usuários** (isolamento Q23 intacto).
- **Convite**: o admin cria/convida contas. Magic-code exige **e-mail válido e
  entregável** (é identidade E canal).
- **Landing page pública** com "**pedir acesso**" → grava um `AccessRequest`
  (email, name?, note?, status pending/approved/rejected). Só o admin enxerga a fila;
  aprovar cria o User e dispara o magic-link. (Controle manual no início pra evitar
  enxurrada de signups.)
- `AccessRequest` é **pré-conta** → fica FORA do isolamento por `user_id`.

## Modelo de dados (a construir — §4 do doc, revisado pelo grilling)

Hierarquia **Client → Project → Task → TimeEntry**, com **Tags** por fora.
⚠️ **Toda tabela de domínio tem `user_id`** (isolamento Q23) — escopar TODA query por
`Current.user`. Tabelas usam **money-rails** (`monetize`) pra valores (Q11/Q20).

| Tabela | Campos-chave | Notas |
|---|---|---|
| `Client` | user_id, name, **rate_cents (default)**, currency (default BRL) | rate = taxa faturável/hora PADRÃO do cliente. Moeda mora aqui. `monetize :rate_cents, allow_nil: true, with_model_currency: :currency`. |
| `Project` | user_id, name, color, client_id (opcional), **rate_cents (override, nulável)** | color → bolinha/gráficos. `rate_cents` preenchida SOBRESCREVE a do cliente; nula HERDA (Q22). client_id opcional (Q2). |
| `Task` | user_id, name, project_id | sub-bucket do projeto (Q1). |
| `TimeEntry` | user_id, **project_id (NULÁVEL)**, task_id (opcional), description (opcional), started_at, ended_at, **rate_cents + currency (SNAPSHOT)**, **billable (bool, null:false, default:true)** | sessão atômica. **Servidor = fonte da verdade**: start grava `started_at` (`Time.current`), stop grava `ended_at`. Ver invariantes abaixo. |
| `Tag` | user_id, name, archived_at | entidade de 1ª classe por usuário (tela própria). |
| `Tagging` | tag_id, time_entry_id | join M:N. **Tag vive no TimeEntry, NÃO na Task** (Q8). |

**Regras de domínio fechadas no grilling (ver grilling-progress.md):**
- **`project_id` é NULÁVEL** (Q15): "entry sem projeto" é estado legítimo (start solto
  estilo Clockify) → rate nil, agrupa em balde "(sem projeto)".
- **Rate efetiva** = `project.rate_cents || project.client&.rate_cents` (override do
  projeto, senão a do cliente, senão nil) (Q22).
- **Snapshot (Q10/Q11)**: `TimeEntry.rate_cents`/`currency` CONGELAM a rate efetiva já
  resolvida no `before_save` (recarimba quando `project_id` muda). Mudar rate do
  cliente/projeto NÃO revaloriza histórico.
- **`task_id`** só válida se `project_id` presente E `task.project_id ==
  entry.project_id`; mexer/limpar `project_id` limpa `task_id` (Q16) — mesmo before_save.
- **Faturável (Q18)** = `billable == true E rate presente` ? `horas × rate` : zero.
  `billable=false` zera o amount mas mantém as HORAS. Default de `billable` segue a
  rate (true se tem rate). Dinheiro arredonda no centavo (ROUND_HALF_UP).
- **Timer único POR USUÁRIO (Q3/Q4/Q14)**: invariante "≤1 TimeEntry com `ended_at IS
  NULL` **por user**", garantida por índice único parcial `UNIQUE(user_id) WHERE
  ended_at IS NULL` + **stop EXPLÍCITO** (start com um rodando → **409**, sem stop
  implícito; clientes re-sincronizam via `GET /timer`). Entry de duração zero é
  descartado (Q15c). Sem coluna `current`/`running` — derivado de `ended_at IS NULL`.
- **Arquivar = soft delete via `archived_at` (Q7)**, concern `Archivable`, SEM
  default_scope, scopes explícitos. Hard-delete só p/ entidade sem entries. Vale p/
  Client, Project, Task, Tag.

## Timezone (§8 do doc, revisado — Q23b)

- Banco em UTC. **Fuso é POR USUÁRIO**: `User.time_zone` (string, `null: false`,
  default `"America/Sao_Paulo"`). Todo corte/exibição lê **`Current.user.time_zone`**
  (não uma constante global).
- Invisível no uso normal. Reaparece **só no corte do dia do relatório**:
  agrupar convertendo pro fuso do user **antes** de extrair a data —
  `.in_time_zone(Current.user.time_zone).to_date`, feito **no Ruby** (SQLite não tem
  `AT TIME ZONE`). Entry pertence inteiro ao dia do `started_at`, sem fatiar (Q6).
- UI de edição do fuso: pendente (campo + default agora; tela de preferências depois).

## Telas (a construir — ordem do brief; ver PDF pro detalhe de cada uma)

Auth (feito) → **Clients → Projects → Tasks → Timer/TimeEntry → Tags → Relatórios →
Export**. Timer global no topo (start/stop sempre acessível). Sidebar: Calendar,
Dashboard, Reports, Projects, Clients, Tags (**sem Team**).

Telas NOVAS abertas pelo grilling (a grillar/detalhar): **landing page pública**
(pedir acesso — Q24), **área de admin** (lista de users + fila `AccessRequest` +
aprovar/recusar — Q24), **preferências do usuário** (fuso etc. — Q23b). Possível
**cobrança** ($1/mês — ver grilling-progress, ainda a decidir).

Relatórios (forma do Clockify, sem dimensões de equipe): barras por dia + total,
donut por projeto, group by (Project/Description/Client/Tag/Task), views Summary /
Detailed. **O export CSV/Excel mensal é o entregável principal.** Em dados: só
consultas e agrupamentos sobre as tabelas existentes.

## Fora de escopo (não construir)

Invoicing/faturamento dos CLIENTES do usuário (export CSV é o entregável; o usuário
fatura seus clientes por fora) · **equipe/colaboração/compartilhamento/papéis
colaborativos** (multi-usuário SIM, mas sem times — Q23) · OAuth/senha/passkey ·
custom fields · estimativas/forecast/budget de projeto · colunas Access/Progress das
telas. (NOTA: a cobrança $1/mês do PRÓPRIO Ponto pelos seus usuários é outra coisa —
está EM DISCUSSÃO, não confundir com invoicing dos clientes do usuário.)

## Convenções

- **Hotwire, não JS avulso.** Sem `<script>` inline em layouts — usar Stimulus
  controllers (vale aqui: o projeto é Rails + Stimulus).
- **Vanilla Rails**: controllers finos chamando model rico; sem camada de services
  por padrão (ver STYLE.md "Controller and model interactions").
- **Dinheiro = money-rails** (`monetize`, Ruby puro sem Node) — Q11/Q20. ⚠️ NUNCA
  serializar objeto `Money` cru em JSON (vira hash gigante); nas rotas da extensão
  expor escalares (`rate_cents` int + `currency` string).
- **Export = .xlsx (caxlsx) + CSV** da mesma matriz de dados (Q20).
- **REST/CRUD**: ação que não mapeia num verbo padrão vira um novo resource (ex.:
  `start`/`stop` do timer → resource próprio), não custom action.
- Português nos comentários/textos de UI; código (nomes, API) em inglês.
