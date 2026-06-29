# Ponto

Time-tracker self-hosted **pessoal (single-user)**, no espírito Clockify/Toggl mas
enxuto, pra rodar no homelab. Rails 8 + Hotwire + SQLite.

## Documentos de referência (leia antes de decidir arquitetura/UI)

- `docs/time-tracker-decisoes.md` — **racional completo** de arquitetura e escopo.
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
- **Single-user**: não existe equipe, compartilhamento, papéis, multi-conta. Onde o
  Clockify mostrar User/Team/Shared/Access, **ignorar**.

## Comandos

```bash
bin/rails server                 # dev (porta 3000)
bin/rails console
bin/rails db:migrate
bin/brakeman -q --no-pager       # segurança — deve dar 0 warnings
bin/rubocop                      # estilo (rubocop-rails-omakase)
```

**Não há suíte de testes** — o app foi gerado com `--skip-test`. Verificação hoje é
por **smoke test manual** (subir o server, exercitar via curl/browser) + brakeman +
rubocop. Se for adicionar testes, confirme antes a escolha de framework.

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

## Modelo de dados (a construir — §4 do doc)

Hierarquia **Client → Project → Task → TimeEntry**, com **Tags** por fora:

| Tabela | Campos-chave | Notas |
|---|---|---|
| `Client` | name, **rate**, currency (default BRL) | rate = taxa faturável/hora, **FIXA por cliente**. Moeda mora aqui. |
| `Project` | name, color, client_id (opcional) | color alimenta bolinha e gráficos. |
| `Task` | name, project_id | — |
| `TimeEntry` | task_id, description, started_at, ended_at | sessão atômica. **Servidor é a fonte da verdade**: start grava `started_at` (`Time.current`), stop grava `ended_at`. |
| `Tag` | name, active | entidade global de 1ª classe (tela própria). |
| `Tagging` | tag_id, time_entry_id | join M:N. **Tag vive no TimeEntry, NÃO na Task.** |

- **Faturável** = `horas × client.rate`.
- **Tudo pendurado num `User` único.**

## Timezone (§8 do doc)

- Banco em UTC; `config.time_zone = "America/Sao_Paulo"` (já setado).
- Invisível no uso normal. Reaparece **só no corte do dia do relatório**:
  agrupar convertendo pro fuso local **antes** de extrair a data —
  `.in_time_zone("America/Sao_Paulo").to_date`, feito **no Ruby** (SQLite não tem
  `AT TIME ZONE`).

## Telas (a construir — ordem do brief; ver PDF pro detalhe de cada uma)

Auth (feito) → **Clients → Projects → Tasks → Timer/TimeEntry → Tags → Relatórios →
Export**. Timer global no topo (start/stop sempre acessível). Sidebar: Calendar,
Dashboard, Reports, Projects, Clients, Tags (**sem Team**).

Relatórios (forma do Clockify, sem dimensões de equipe): barras por dia + total,
donut por projeto, group by (Project/Description/Client/Tag/Task), views Summary /
Detailed. **O export CSV/Excel mensal é o entregável principal.** Em dados: só
consultas e agrupamentos sobre as tabelas existentes.

## Fora de escopo (não construir)

Invoicing/faturamento (export CSV é o entregável; fatura-se por fora) ·
multi-usuário/equipe/compartilhamento/papéis · OAuth/senha/passkey · custom fields ·
estimativas/forecast/budget de projeto · colunas Access/Progress das telas.

## Convenções

- **Hotwire, não JS avulso.** Sem `<script>` inline em layouts — usar Stimulus
  controllers (vale aqui: o projeto é Rails + Stimulus).
- **Vanilla Rails**: controllers finos chamando model rico; sem camada de services
  por padrão (ver STYLE.md "Controller and model interactions").
- **REST/CRUD**: ação que não mapeia num verbo padrão vira um novo resource (ex.:
  `start`/`stop` do timer → resource próprio), não custom action.
- Português nos comentários/textos de UI; código (nomes, API) em inglês.
