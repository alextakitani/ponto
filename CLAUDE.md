# Ponto

Time-tracker self-hosted **multi-usuário, sem colaboração/times** (cada usuário tem
sua própria bolha isolada de dados), no espírito Clockify/Toggl mas enxuto, pra rodar
no homelab e ser publicado com **código aberto (licença O'Saasy — proibido revender como SaaS; ver `LICENSE.md`, Q78)**. Rails 8 + Hotwire + SQLite.

> ⚠️ **Esta CLAUDE.md foi reconciliada (02/07/2026) com as decisões de design do
> grilling — que está COMPLETO (Q1–Q76, todos os ramos fechados).** A fonte de
> verdade detalhada e o RACIONAL de cada decisão estão em
> **`docs/grilling-progress.md`**. Onde esta CLAUDE.md e o grilling-progress
> divergirem, o grilling-progress vence (é mais novo e mais detalhado). Premissas
> originais que MUDARAM: o app NÃO é single-user no sentido de "um registro de User"
> (ver Stack), `project_id` é nulável, a rate tem override por projeto, há
> admin/convite/landing, a estética **NÃO é mais retrô** — é moderna minimal densa
> (Q63) — e há um **CLI oficial** (`ponto-cli`, Q73–Q76). Único tema em aberto:
> cobrança $1/mês (adiada).

## Documentos de referência (leia antes de decidir arquitetura/UI)

- `docs/grilling-progress.md` — **decisões de design fechadas (Q1–Q76) + racional.**
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
  sem offline sync. SW cacheia SÓ uma página offline estática (Q69); manifest com
  cores dos tokens + ícone real a fazer (hoje são defaults do Rails).
- **CSS**: custom properties zero-build, estilo fizzy (Q62 — decidido; sem Tailwind).
  Tokens SEMÂNTICOS (`--surface`/`--text`/`--accent`) com valores pros DOIS temas.
- **Estética: MODERNA minimal densa, estilo Linear** (Q63 — revoga o "retrô anos 90"
  do brief): base neutra, 1 acento, linhas densas sem cards/bordas, hierarquia por
  tipografia/peso/espaço; personalidade = cores dos projetos; assinatura = barra do
  timer. **Claro + dark AUTOMÁTICO** via `prefers-color-scheme`, sem toggle (Q64).
  Fonte: **Inter variable self-hosted** (woff2 em assets, `tabular-nums` em colunas
  numéricas — Q70). Gráficos do relatório = **SVG server-rendered** em partial ERB,
  zero JS (Q71).
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

## API JSON + CLI `ponto-cli` (Q73–Q76)

- **Superfície JSON TOTAL (Q73):** todo resource de domínio responde JSON
  (`respond_to` + views `.json.jbuilder`, MESMAS rotas — padrão fizzy): catálogo
  (Clients/Projects/Tasks/Tags) + timer + time_entries + report + export. **Só-web
  (fora do JSON):** auth de browser, admin, import. Escalares no JSON (Q11), erros
  padronizados (`{error:}` + status correto). Implementar o `format.json` JUNTO com
  cada controller ao nascer.
- **CLI oficial (Q74):** repo separado `ponto-cli`, **Go, fork estrutural do
  `fizzy-cli`** (que é MIT — pode adaptar, não só estudar; clonado em
  `~/Projetos/fizzy-cli`). Herda envelope `{ok,data,summary,breadcrumbs}`, `--jq`,
  profiles, doctor, skill/plugin Claude. Auth = o mesmo `AccessToken` da extensão
  (gerado em Preferências — Q66).
- **Nasce incremental pós-fatia-Timer (Q75):** timer/entry/catálogo primeiro;
  report/export quando o app os tiver. Config (Q76): `api_url` OBRIGATÓRIA no setup
  (self-hosted), profiles prod/dev, env `PONTO_*`, default project opcional,
  `ponto setup claude`.

### Acesso por CONVITE (a construir — Q24)

Não há signup público auto-servido. Acesso é controlado:

- **Bootstrap do admin**: no PRIMEIRO acesso, sem nenhuma conta no banco, o app cria
  o **admin geral** (primeiro user = admin). `admin` é um **boolean no `User`** (não
  roles). Papel OPERACIONAL: gerencia contas/convites/pedidos; **NÃO vê dados de
  domínio de outros usuários** (isolamento Q23 intacto).
- **Bootstrap**: o 1º admin nasce via `ENV["ADMIN_EMAIL"]` (Q37) — com o banco vazio,
  só esse e-mail consegue criar conta (e vira admin); depois fica inerte. É o ÚNICO
  caminho de bootstrap (sem fallback "1º a logar vira admin"). Ver `.env.example`.
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
- UI de edição do fuso: na tela de **Preferências** (`/preferences` — Q66).

## Telas (a construir — ordem do brief; ver PDF pro detalhe de cada uma)

Auth (feito) → **Clients → Projects → Tasks → Timer/TimeEntry → Tags → Relatórios →
Export**. Timer global no topo em TODA tela (start/stop sempre acessível — é a
assinatura visual, Q63). **URLs (Q61):** `/` = landing pública (Q36); home do logado
= `/time_entries` (tracker); resources no topo, sem namespace (contrato da extensão
Q9/Q13); só admin é namespaced (`/admin`).

**Navegação (Q60/Q65):** desktop = sidebar **Tracker · Reports · Projects · Clients ·
Tags** (+ Preferências/Admin no rodapé). Mobile (PWA) = **bottom tab bar** Tracker ·
Reports · Projects · Mais (Mais → Clients/Tags/Preferências/Admin). **Calendar e
Dashboard foram CORTADOS** (Q60 — Dashboard duplica o Summary; Calendar é caro).

Telas novas já DESENHADAS no grilling: **landing 1 dobra** (Q67), **admin em página
única** com fila de pedidos + tabela de users (Q68), **Preferências em 3 seções**
(perfil/fuso · tokens da extensão · export/import dos dados — Q66/Q72).

Relatórios (fechado — Q53–Q58): views **Summary · Detailed** (Weekly cortada, Q55);
período enxuto + setas ‹› default "Este mês" (Q53); 6 filtros OR/AND (Q54); rounding
por entry opt-in (Q56); entry rodando FORA do report (Q57); tudo via **PORO `Report`**
(1 query SQL + pipeline Ruby → Summary/Detailed/export da mesma matriz — Q58).
**O export CSV/Excel mensal é o entregável principal.**

## Fora de escopo (não construir)

Invoicing/faturamento dos CLIENTES do usuário (export CSV é o entregável; o usuário
fatura seus clientes por fora) · **equipe/colaboração/compartilhamento/papéis
colaborativos** (multi-usuário SIM, mas sem times — Q23) · OAuth/senha/passkey ·
custom fields · estimativas/forecast/budget de projeto · colunas Access/Progress das
telas · **Timesheet** (grade semanal de entrada — Q59: duração-pura conflita com a
Q5) · **Calendar e Dashboard** (Q60) · view **Weekly** do relatório (Q55) ·
conversão de câmbio (Q43: nunca somar moedas; subtotais por moeda). (NOTA: a
cobrança $1/mês do PRÓPRIO Ponto pelos seus usuários é outra coisa — está ADIADA,
não confundir com invoicing dos clientes do usuário.)

## Convenções

- **Hotwire, não JS avulso.** Sem `<script>` inline em layouts — usar Stimulus
  controllers (vale aqui: o projeto é Rails + Stimulus).
- **Vanilla Rails**: controllers finos chamando model rico; sem camada de services
  por padrão (ver STYLE.md "Controller and model interactions").
- **Autorização = Action Policy** (Q40/Q41): a gem carrega a camada INTEIRA de
  "pode/não pode" — isolamento por tenant (`relation_scope`), `admin?`, suspensão.
  Sem papéis colaborativos (Q23).
- **Dinheiro = money-rails** (`monetize`, Ruby puro sem Node) — Q11/Q20. ⚠️ NUNCA
  serializar objeto `Money` cru em JSON (vira hash gigante); nas rotas da extensão
  expor escalares (`rate_cents` int + `currency` string).
- **Export = .xlsx (caxlsx) + CSV** da mesma matriz de dados (Q20).
- **REST/CRUD**: ação que não mapeia num verbo padrão vira um novo resource (ex.:
  `start`/`stop` do timer → resource próprio), não custom action.
- Português nos comentários/textos de UI; código (nomes, API) em inglês.
