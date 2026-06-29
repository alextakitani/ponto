# Time Tracker — Registro de Decisões

> Documento de decisões de arquitetura e escopo para um time-tracker self-hosted pessoal.
> Última atualização: 29/06/2026
> Status: design fechado na auth e no modelo de dados. Implementação não iniciada.

---

## 1. Visão geral

Time-tracker self-hosted para **uso pessoal**, no espírito Clockify/Toggl mas enxuto, rodando no homelab.

- **Referência de implementação:** [`basecamp/fizzy`](https://github.com/basecamp/fizzy) (Rails + Hotwire). Clonar os *padrões*, não o código.
- **Atenção à licença:** o Fizzy usa a "O'Saasy License" (não é OSI/MIT). Estudar e reescrever no projeto próprio — não copiar trechos tratando como open-source padrão.

---

## 2. Stack

| Camada | Escolha | Motivo |
|---|---|---|
| Backend | **Rails** (não Laravel) | Velocidade de entrega no stack já dominado. Consumo de container seria irrelevante na conta de luz. |
| Frontend | **Hotwire** (Turbo + Stimulus) | Interatividade necessária é mínima. **Não** SPA, **não** Inertia/React. |
| Mobile | **PWA** (mesma UI responsiva + manifest + service worker) | PWA roda *em cima* do Hotwire — não compete com ele. É o que o Fizzy faz. |
| Banco | **SQLite** | Leve, backup = um arquivo. Empurra trabalho de timezone pra camada de aplicação (sem `AT TIME ZONE`). |
| Assets | **importmap** | Sem build de JS no runtime, container magro. |

**Offline sync:** fora de escopo. Online-only — sincronizar entries criadas offline traz conflito de horário que não se paga.

### Por que não usar pronto
- **Kimai:** removeu SQLite de propósito em 2021; hoje exige MySQL/MariaDB.
- **TimeTagger:** melhor opção SQLite de prateleira, mas optou-se por construir.
- **Solidtime/Kimai:** bancos grandes.

---

## 3. Autenticação

Clone da abordagem do Fizzy: **passwordless puro**.

- **Sem** senha, **sem** Devise, **sem** OmniAuth, **sem** OAuth (Google/GitHub cortados).
- **Entrada humana:** magic link de **código de 6 dígitos**.
  - Expira em **15 min**, **uso único** (consome-e-destrói).
  - Fluxo de **duas etapas na mesma aba** (Turbo Stream troca form de e-mail pelo de código). Bom pra cross-device: recebe no celular, digita no desktop.
  - Segurança do esquema = **rate limit (obrigatório) + expiração curta + uso único**. Sem contador de tentativas (teatro pro modelo de ameaça).
- **Extensão de Chrome:** autentica por **AccessToken** (bearer, escopado por método HTTP). Gerado uma vez no app, colado nas opções da extensão. **Não é dispensável.**
  - O "authkey" dispensado era a **passkey** (WebAuthn) — fora por ora.
- **Concern de auth único:** tenta cookie → senão bearer (só em JSON) → senão exige login.
  - Consequência: talvez **não** sejam necessários dois controllers separados; o concern resolve a dupla credencial.
- **Multi-tenancy do Fizzy colapsada:** `Identity → Users → Accounts` vira **um `User` só**. `Session belongs_to :user`. Sem tabela de identities, sem accounts.

---

## 4. Modelo de dados

Hierarquia: **Client → Project → Task → TimeEntry**, com **Tags** por fora.

```
User (único)
 └─ Client        (nome, rate, currency)
     └─ Project   (nome, cor, client_id [opcional])
         └─ Task  (nome, project_id)
             └─ TimeEntry (task_id, description, started_at, ended_at)
                  └─ Tagging  (join M:N)
                       └─ Tag  (entidade global de 1ª classe)
```

- **`TimeEntry`** é a sessão atômica. **Servidor é a fonte da verdade**: start grava `started_at` (`Time.current`), stop grava `ended_at`.
- **Tag vive no `TimeEntry`** (estilo Clockify — decidido pelos screenshots), **não** na task.
- **`Tag`** é entidade global gerenciável (tela própria), não string solta.

---

## 5. Taxa faturável

- **Fixa por cliente.** Sem variação entre projetos, sem override, sem cascata.
- **Moeda** também mora no cliente.
- Faturável = `horas × client.rate`.

---

## 6. Fora de escopo (explícito)

- **Invoicing / faturamento.** O **export CSV/Excel no fim do mês é o entregável**; fatura-se por fora.
- **Multi-usuário / equipe / compartilhamento.**
- **OAuth, senha, passkey** (por ora).

---

## 7. Relatórios

Quer-se a **forma** dos relatórios do Clockify, **sem** dimensões de usuário/equipe:

- Gráfico de barras por dia.
- Donut por projeto.
- Agrupamento (por projeto/descrição).
- Detalhado linha-a-linha com tag + duração.
- Views Summary / Detailed.

Em dados: apenas **consultas e agrupamentos** sobre as tabelas existentes. Nenhuma estrutura nova.

---

## 8. Timezone

- **Banco em UTC** (default do Rails — não lutar contra). `config.time_zone = "America/Sao_Paulo"`.
- Invisível no uso normal: grava e lê sempre em horário de SP.
- **Único ponto onde reaparece de propósito:** o corte do dia no relatório.
  - Agrupar convertendo pro fuso local **antes** de extrair a data: `.in_time_zone("America/Sao_Paulo").to_date`.
  - Feito **no Ruby** (SQLite não tem `AT TIME ZONE` nativo).
- Protege contra bordas (DST, viagem) sem custo no caso comum.

---

## 9. Extensão de Chrome (esboço — não fechado em detalhe)

- **Manifest V3.** `popup.html` + `popup.js` em JS puro.
- **Servidor é a fonte da verdade do timer** (não guarda contador na extensão).
- **~4 rotas JSON:** start, stop, current, tags.
- **Token** no `chrome.storage`, enviado como `Authorization: Bearer`.
- **Service worker MV3 é efêmero** — só importa se quiser badge com tempo ao vivo (aí `chrome.alarms`).
- Precisa de **config de CORS** pro origin `chrome-extension://`.
- A extensão **não** cobre mobile — lá usa-se o PWA.

---

## 10. Frentes ainda abertas

- [ ] Fluxo detalhado da extensão (rotas JSON × modelo).
- [ ] Relatório/export mensal (consultas de agrupamento + formato de saída).
- [ ] UI web/PWA (telas Hotwire).
