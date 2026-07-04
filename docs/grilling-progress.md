# Grilling — Ponto (time-tracker) — progresso

> Sessão de grilling (/grilling) sobre as frentes em aberto do design.
> Última sessão: 02/07/2026. **🏁 GRILLING COMPLETO — Q1–Q76, TODOS os ramos
> fechados.** Único tema em aberto: cobrança $1/mês (💤 ADIADA por decisão do Alex).
> O que resta é IMPLEMENTAÇÃO (ordem: Q39 catálogo-primeiro; pendências de auth
> listadas na seção "Frentes"). ✅ CLAUDE.md re-reconciliada em 02/07 (Q52–Q76).
> **Ramo CLI: FECHADO** (Q73–Q76, aberto pelo Alex após o 1º fecho): superfície
> JSON total no app; `ponto-cli` em Go = fork estrutural do fizzy-cli (MIT);
> nasce incremental pós-Timer; config herdada com adaptações self-hosted.
> **Ramo TELAS: FECHADO** (Q60–Q71): Calendar/Dashboard/Timesheet cortados,
> URLs/home, CSS custom-properties, **estética MODERNA minimal densa (Linear) —
> REVOGA o retrô**, dark automático, bottom tabs no mobile, Preferências, landing
> 1 dobra, admin 1 página, PWA c/ página offline, Inter, SVG server-rendered.
> **Ramo IMPORTADOR: FECHADO** (Q72): JSON único versionado, import só em bolha vazia.
> **Ramo Auth/convite/admin/landing: FECHADO** (Q27 escolheu o ramo; Q28–Q38).
> **Ramo Modelo de dados / telas de domínio: FECHADO** (Q39–Q52):
> ordem de build, Action Policy p/ authz+isolamento, moeda por Client, mix de moedas,
> unicidade de nome, rate UX, entry manual, Split/Duplicate, edição inline, seletores,
> Tags UI/inline-create, cor do Project (paleta fixa — Q52).
> **Ramo Relatório/Export: FECHADO** (Q18–Q21, Q43, Q53–Q58): período enxuto+setas,
> 6 filtros OR/AND, Weekly cortada, rounding por-entry, rodando fora do report,
> PORO `Report` (1 query + pipeline Ruby). Restam: TELAS, Importador, Timesheet.
> Revisões importantes: Q3/Q4 revisadas pela Q14; Q1 parcialmente revogada pela Q15;
> Q11 estendida pela Q18; **Q23 revoga o "single-user/User-único" → app MULTI-USUÁRIO**;
> Q24 = acesso por CONVITE + admin + landing; Q25 = privacidade/encryption;
> Q26 = export/portabilidade.
> 💤 **Cobrança $1/mês = ADIADA explicitamente** (Alex: "não quero grilar agora,
> cobrança vou fazer depois"). Esboço registrado abaixo, NÃO grillado.
> ✅ **CLAUDE.md reconciliada em 30/06** com Q1–Q24 (multi-user, rate override,
> project_id nulável, billable, convite/admin, fuso por user, money-rails, export).
> **Ramo da extensão de Chrome: FECHADO 100%** (Q9, Q12, Q13, Q14, Q15, Q17).
> (Ref do ramo Relatório: xlsx real do Clockify em
> `~/Dropbox/empresa/Kube/invoices/2026/Clockify_Time_Report_Detailed_05_01_2026-05_31_2026.xlsx`.)

## Como retomar
Rodar `/grilling` de novo e dizer "continuar de onde paramos, ver `docs/grilling-progress.md`".
As decisões abaixo já estão FECHADAS — não re-discutir, só aplicar quando for implementar.
Conversa em **português**.

## Decisões fechadas nesta sessão

- **Q1 — Task opcional.** `TimeEntry` aponta pro `Project`; `task_id` opcional. A
  rate vem do Client via Project; a Task fica fora do caminho do dinheiro (é só
  sub-bucket de organização).
  ⚠️ **PARCIALMENTE REVOGADA na Q15:** `project_id` NÃO é mais obrigatório — virou
  NULÁVEL. "Entry sem projeto" é estado legítimo (start solto, modelo Clockify). O
  resto da Q1 (task opcional, rate vem via Project) continua valendo. Ver Q15.

- **Q2 — Projeto sem cliente.** `client_id` segue opcional no Project. Projeto sem
  cliente: horas contam em todos os relatórios/gráficos; valor em dinheiro = zero/vazio.
  Sem inventar "cliente interno" fantasma.

- **Q3 — Timer único global.** Invariante: no máximo um `TimeEntry` com
  `ended_at IS NULL`. Rota `current` retorna objeto ou null, nunca lista.
  ⚠️ **REVISADO na Q14:** o "stop implícito" original FOI ABANDONADO. Stop é
  EXPLÍCITO (modelo Clockify) — start com um timer rodando NÃO para o anterior
  automaticamente; o servidor RECUSA (409). Ver Q14.

- **Q4 — Garantia da invariante.** Índice único parcial no SQLite
  (`WHERE ended_at IS NULL`) como rede de segurança no banco. **Sem** coluna
  `current`/`running` — o entry atual é derivado de `ended_at IS NULL`.
  ⚠️ **REVISADO na Q14:** o "para-e-troca na aplicação" (auto-stop do anterior) foi
  abandonado junto com o stop implícito. Na app, `POST /timer` com um rodando vira
  409, não troca. O índice único vira a última linha de defesa contra a race; a
  primeira linha é a recusa 409 + clientes re-sincronizando. Ver Q14.

- **Q5 — Entry manual sim, duração-pura não.** Suportar entry manual (mesmo modelo,
  validação `ended_at > started_at` sempre aplicada). Sem modo duração-pura: todo entry
  finalizado tem os dois timestamps reais. "2h30 ontem" se registra via início+fim
  (ou início+duração que calcula o fim). Único com `ended_at` nulo = o que está rodando.

- **Q6 — Corte do dia.** Entry pertence inteiro ao dia do `started_at`
  (`.in_time_zone("America/Sao_Paulo").to_date`), **sem fatiar** na meia-noite.
  Preserva "uma linha = um entry"; erro de borda na barra é cosmético e documentado.

- **Q7 — Arquivar = soft delete, SEM gem.** Um único conceito "fora de uso" via
  `archived_at` (timestamp nulável). Concern `Archivable` (`archive!`/`unarchive!`).
  **Sem `default_scope`** — scopes explícitos (`active`/`archived`); relatório enxerga
  tudo por padrão. Hard-delete físico só pra entidade **sem entries**
  (`restrict_with_error`). Vale p/ Client, Project, Task, Tag. (Rejeitada a gem
  `paranoia`/`discard`: default scope morde o relatório + contradiz "padrões do fizzy".)

- **Q8 — Tags/filtros no histórico.** Exibição histórica é fiel (mostra tags reais,
  arquivadas ou não). Seletor de taggear (entry novo/editar) só ativas (+ as que o
  entry já tem). **Filtro do relatório se baseia no que existe no período**, não no
  `active` atual — vale p/ Tag, Project e Client.

- **Q9 — Rotas da extensão.** Mesmas rotas da web respondendo JSON (`respond_to`
  decide HTML/Turbo vs JSON); uma fonte de verdade pra lógica de timer — extensão e web
  não podem divergir na invariante "um timer só". **Sem** namespace `/api`, sem
  versionamento (app pessoal, um cliente, você controla os dois lados).

- **Q10 — Rate histórica = CONGELADA (snapshot).** Mudar a `rate` do cliente NÃO
  revaloriza histórico. O valor faturável é congelado por `TimeEntry`. (Mundo B.)
  Motivo: export CSV mensal é artefato arquivável — número de Janeiro não pode mudar
  em Junho. "Rate fixa por cliente" na CLAUDE.md = "rate mora no Client", não
  "rate imutável".

- **Q11 — money-rails + snapshot no TimeEntry. FECHADA.**
  Pesquisa (agent, 30/06): money-rails 3.0.0 viva, Rails 8 + Minitest OK, zero
  Node/asset, SQLite agnóstico. Fizzy não tem precedente (não lida com dinheiro).
  - `Client`: `monetize :rate_cents, allow_nil: true, with_model_currency: :currency`
    (coluna `currency`, default "BRL"). nil = sem rate.
  - `TimeEntry`: snapshot — colunas `rate_cents` + `currency`, recarimbadas em
    `before_save` quando `project_id` muda (Q11a). Faturável = nil se rate nil, senão
    horas × rate.
  - ⚠️ **JSON**: NUNCA serializar Money cru (vira hash gigante — issues #393/#42).
    Nas rotas da extensão, expor escalares (`rate_cents` int + `currency` string).
    Tratar como invariante quando grillar o contrato da extensão.
  - **Arredondamento**: dinheiro sempre no centavo (ROUND_HALF_UP). Toggle "Rounding"
    do relatório = arredondar TEMPO (duração), opt-in, decisão adiada pro front de
    Relatórios (não afeta schema). Toggle EXISTE; bloco/direção (5/15/30 min, pra
    cima vs mais próximo) e granularidade (por entry vs por grupo) decididos no front
    de Relatórios — dependem de como o relatório agrupa.

- **Q12 — Escopo da extensão de Chrome. FECHADA.** (Decidida vendo prints do popup
  Clockify.) A extensão captura/edita o "AGORA"; o app faz a revisão rica.
  **Extensão FAZ:** start rápido (usa um **default project** configurado na própria
  extensão → start em 1 clique), ver atual, stop, **editar o entry** (descrição,
  projeto, task, tags, start time — paridade com o app no que toca a capturar/ajustar
  tempo), lista recente simples (últimos N, lista chapada), re-disparar (▶) um entry.
  **Extensão NÃO faz:** histórico agrupado com totais semana/dia, autocomplete de
  entries recentes, relatórios, export, CRUD de catálogo (Client/Project/Task/Tag).
  Esses ficam só no app. Racional: cada campo/feature a mais num popup apertado é UI
  a mais pra manter, e duplica o que o app já mostra melhor.

- **Q13 — start/stop = resource `timer` singular. FECHADA.** Honra a regra da
  CLAUDE.md ("ação sem verbo padrão vira resource"). Dois resources:
  - `timer` (SINGULAR — o "timer atual", singleton conceitual da invariante Q3/Q4):
    `GET /timer` → entry rodando ou null (= `current` da Q3); `POST /timer` → start
    (cria entry + para o anterior; payload `project_id?` cai no default se omitido,
    `description?`); `DELETE /timer` → stop (carimba `ended_at`). Fonte ÚNICA da
    lógica de timer (Q9).
  - `time_entries` (PLURAL — CRUD vanilla do registro): `index` (lista recente),
    `show`, `update` (editar campos — img 3 da extensão), `destroy`, `create` (entry
    manual Q5).
  - **▶ re-disparar** (Q12) = `POST /timer` com project_id/description copiados de um
    entry antigo. SEM rota nova — start com payload pré-preenchido pelo cliente.

- **Q14 — Stop EXPLÍCITO puro (modelo Clockify). FECHADA.** (Decidida vendo prints:
  quando há timer rodando, o botão vira STOP vermelho; não existe um segundo START.)
  - **UI/extensão:** replica o Clockify — botão vira STOP quando há um rodando; NÃO
    oferece START enquanto não parar. O cliente só descobre "tem um rodando" via
    `GET /timer` ao carregar.
  - **Servidor:** `POST /timer` com um já rodando → **409 Conflict**, SEM exceção
    (sem stop implícito, sem para-e-troca). A invariante "um só" é garantida por
    RECUSA, não por correção.
  - **Clientes tratam o 409:** ao receber, fazem `GET /timer`, veem o que realmente
    roda, atualizam a tela ("já tem um rodando: X"). Handler de erro a mais na
    extensão e no JS da web — preço aceito em troca de nunca ter stop-surpresa.
  - O 409 só dispara em race verdadeira (os dois lados com estado velho mandam START
    quase juntos); no uso normal a UI já impede o segundo start.
  - **Start mínimo:** ver Q15 (detalhes ratificados lá; o (b) mudou — projeto NÃO é
    obrigatório no start).

- **Q15 — Start mínimo + `project_id` NULÁVEL. FECHADA.** (Revoga "project_id
  obrigatório" da Q1.)
  - **(a) Descrição opcional.** START com "What are you working on?" vazio é válido
    (modelo Clockify); preenche depois.
  - **(b) `project_id` NULÁVEL — start SEM projeto é permitido.** O Clockify deixa
    dar start solto (sem projeto); você atribui projeto depois. Logo o modelo NÃO
    pode exigir project_id. "Entry sem projeto" = estado de 1ª classe: conta horas,
    rate = nil (não faturável), agrupa em balde "(sem projeto)" nos relatórios.
    Mesma filosofia da Q2 (projeto sem cliente) um nível acima. NÃO há "obrigatório
    só no stop" (Forma B rejeitada — criaria entry travado/erro chato no stop). Na
    extensão, o projeto fica pré-selecionado (último usado / default opcional como
    CONVENIÊNCIA, não pré-requisito); pode-se dar start sem seleção.
  - **(c) Duração-zero descartada.** Entry com `ended_at == started_at` (clique
    duplo/race) → DELETADO, não fechado inválido (não viola `ended_at > started_at`
    da Q5). Com stop explícito (Q14) é raro, mas a guarda fica. Alternativa
    (rejeitar o stop) deixaria timer preso — pior UX.
  - **Consequências a propagar:** Q11 (rate) e relatórios (Q8) já tratam
    `project_id IS NULL` → rate nil, balde "(sem projeto)". Trivial, já é o espírito
    da Q2.

- **Q16 — Integridade Task↔Project no TimeEntry. FECHADA.** (Decorre da Q15: se
  entry pode não ter projeto, a task pendurada precisa de regra.)
  - **(a)** `task_id` válida ⟹ `project_id` PRESENTE **E** `task.project_id ==
    entry.project_id` (a task escolhida tem que ser filha do project escolhido). Não
    pode `project=B, task=X-do-A`. Não pode task com entry sem projeto.
  - **(b)** Mudar OU limpar `project_id` → **limpa `task_id` automaticamente** (no
    MESMO `before_save` que recarimba rate/currency da Q11). Trocar projeto invalida a
    task antiga; você reescolhe se quiser.
  - Rejeitada a alternativa frouxa (deixar task órfã e ignorar no relatório) — sujaria
    o dado.

- **Q17 — CORS pra `chrome-extension://`. FECHADA.** (Último item aberto da Q9 — o
  mapeamento token read/write × verbo JÁ está implementado: `AccessToken#allows?` +
  `User.find_by_permissable_access_token(token, method:)`; nada a grillar lá.)
  - **(a)** SIM configurar CORS — não depender do comportamento "privilegiado" do
    Chrome (varia); tratar como cross-origin explícito.
  - **(b)** À MÃO num concern pequeno (seta headers + trata preflight `OPTIONS`),
    aplicado só nas rotas JSON da extensão. SEM gem `rack-cors` — alinhado ao vanilla
    Rails enxuto / espírito de não puxar gem (igual rejeição da paranoia na Q7).
  - **(c)** Origin permitido = `chrome-extension://<seu-id>` CONFIGURÁVEL
    (env/credentials), fallback liberal em DEV. Não abrir `*` em prod, mas pode ser
    frouxo: **a segurança real é o Bearer token**; CORS é só higiene pro browser
    deixar o fetch passar. (ID muda entre dev-unpacked e publicada.)

- **Q18 — Flag `billable` por entry. FECHADA.** (Decidida vendo o xlsx real: coluna
  `Billable` Yes/No, separada de ter rate.) Adotado o flag explícito (Posição B).
  - **(a)** Default: `billable = true` SE o entry tem rate (projeto com cliente);
    `false` se não tem rate. O default SEGUE a rate, mas é sobrescrevível.
  - **(b)** Cálculo: `Billable Amount = (billable==true E rate presente) ? horas×rate
    : zero/vazio`. Marcar `billable=false` num entry COM rate → some do faturamento,
    mas as HORAS continuam contando nos relatórios de tempo (igual Clockify Billable=No).
  - **(c)** Coluna booleana PURA: `null: false, default: true`. Sem três estados.
  - ⚠️ **ESTENDE a Q11:** "faturável" deixa de ser só "tem rate" → agora é "rate
    presente **E** billable=true". `rate_cents` (snapshot Q11) NÃO é apagado por
    billable=false — só ignorado no amount (remarcar true faz o valor voltar).
  - Motivo de aceitar (apesar do histórico ser 100% "Yes"): você quer poder excluir
    um entry do faturamento sem tirar o projeto/rate.

- **Q19 — Colunas do export "Detailed". FECHADA.** (Partindo das 18 colunas do xlsx
  real, removendo as de equipe.) **14 colunas, uma linha por TimeEntry:**
  1. Project (`project.name`, vazio se sem projeto — Q15)
  2. Client (`project.client.name`)
  3. Description
  4. Task (`task.name`)
  5. Tags (join taggings, separadas por vírgula)
  6. Billable ("Yes"/"No" — Q18)
  7. Start Date (started_at → data LOCAL)
  8. Start Time (started_at → hora LOCAL)
  9. End Date (ended_at → data LOCAL)
  10. End Time (ended_at → hora LOCAL)
  11. Duration (h) — HH:MM:SS
  12. Duration (decimal) — horas decimais
  13. Billable Rate (BRL) — snapshot rate_cents (Q11)
  14. Billable Amount (BRL) — cálculo (Q18)
  - **CORTADAS:** User, Group, Email (equipe — single-user), Date of creation (ruído
    p/ faturamento; fatura-se por start/end, não por quando digitou).
  - **(a) Moeda no HEADER** (`Billable Rate (BRL)`), célula numérica pura (bom p/ somar
    no Excel) — **assume MOEDA ÚNICA por export**. Se um dia houver mix BRL/EUR no
    período: separar por moeda OU pôr moeda em coluna (decisão futura, não agora).
  - **(b) Duração DUPLA** (HH:MM:SS legível + decimal pra multiplicar/somar) — manter
    as duas, custo zero.
  - Confirmado pelo xlsx: Clockify multiplica a DURAÇÃO REAL pela rate e arredonda só
    no fim, no centavo (1h25m × 38.4 = 54.40, não 1.42×38.4). Casa com Q11.

- **Q20 — Formato de export = .xlsx + CSV. FECHADA.**
  - **.xlsx via `caxlsx`** (Ruby puro, sem Node, mantida) = principal. Dá formatação
    real (datas como datas, números somáveis, header estilizado) — é o que você já
    arquiva no Dropbox/manda pro cliente. Só CSV seria downgrade do status quo.
  - **CSV de brinde** da MESMA matriz de dados (linhas×colunas), via stdlib `CSV`
    (~5 linhas, zero gem extra). Alternativa leve.
  - A restrição da CLAUDE.md é Node/build-de-JS, não "zero gems"; caxlsx não fere
    (já puxamos money-rails). Arquitetar: montar a matriz uma vez → xlsx E csv saem dela.

- **Q21 — Relatório Summary (agrupado). FECHADA.** (Decidida navegando o Clockify
  AO VIVO no Chrome do Alex — sessão 30/06.)
  - **Group-by de DOIS níveis ANINHADOS** (revisei minha recomendação inicial de 1
    nível): nível 1 + nível 2 opcional. Confirmado ao vivo: agrupando Project→Description,
    expandir "LaKube" quebra em "Astro 69:05:53 / 2.653,37" + "Backoffice 125:12:12 /
    4.807,81", somando o total do projeto. Dimensões: Project/Client/Task/Tag/Description.
    UI = árvore expansível (Hotwire: Turbo Frame por linha).
  - **Tabela do Summary:** `TITLE | DURATION | AMOUNT` + contador de itens no grupo
    (o "2"/"3") + linha de total. Cabeçalho do relatório mostra 3 métricas:
    **Total (tempo) · Billable (tempo faturável) · Amount (R$)**.
  - **Summary TAMBÉM exporta** (PDF/CSV/Excel — menu EXPORT confirmado ao vivo: "Save
    as PDF / CSV / Excel / Customization"). Nós: CSV+Excel (Q20), sem PDF.
  - **Baldes "(sem projeto/cliente/task)"** explícitos (confirmado: seletor mostra "No
    Project" e agrupa "NO CLIENT" — Q2/Q15).
  - **group-by-Tag pode somar > total** (entry com N tags conta em N grupos) — esperado,
    documentar. (Clockify faz igual.)
  - **Donut** por grupo à direita, total no centro.
  - **Gráfico de barras = uma barra POR DIA** do período (altura = horas do dia) —
    materializa o corte do dia da Q6.
  - **Filtro ≠ group-by:** linha de filtros (Client/Project/Task/Tag/Status/Description)
    é dimensão separada do group-by. Filtra por X, agrupa por Y.

- **Q22 — Rate no Client (default) + override opcional no Project. FECHADA.**
  (Resolve a divergência CLAUDE.md vs Clockify que o tour expôs. Padrão "default +
  override".)
  - **`Client.rate`** = rate PADRÃO do cliente (caso comum: cobra igual em tudo).
  - **`Project.rate`** = OPCIONAL, NULÁVEL. Preenchida → SOBRESCREVE a do cliente
    pra aquele projeto. Nula → HERDA `client.rate`.
  - **Rate efetiva** (no momento do snapshot Q11) = `project.rate || project.client&.rate`
    (override do projeto, senão a do cliente, senão nil = sem projeto/sem cliente).
  - `TimeEntry.rate_cents` (snapshot Q11) congela a **rate EFETIVA já resolvida** — o
    relatório nunca re-resolve a cascata depois. Q10 intacta: mudar Client.rate OU
    Project.rate NÃO altera snapshots passados, só vale daí pra frente.
  - **Currency** continua no Client (Q11; confirmado no tour — Client tem currency, não
    rate, no Clockify; nós colocamos os dois no Client + override de rate no Project).
  - Preserva 100% o caso do Alex (só preenche Client.rate, nunca toca Project.rate →
    idêntico à CLAUDE.md pura) e abre o granular sem complicar o caminho comum.
  - **PRINCÍPIO (open source):** o projeto vai ser publicado OPEN SOURCE, mas começa
    SINGLE-USER. Open source ≠ construir multi-user/features especulativas agora.
    Regra: manter modelo LIMPO E EXTENSÍVEL, aceitar forks/PRs pra outros casos de uso.
    Rate-por-projeto é barato+plausível pro Alex → acomodar. Multi-user é caro+muda
    tudo → resistir até sinal real. Decisões de peso diferente.
  - ✅ **FEITO:** CLAUDE.md atualizada (reconciliação 30/06) — Client.rate (default) +
    Project.rate (override nulável).

- **Q23 — APP É MULTI-USUÁRIO (isolamento total por `user_id`). FECHADA.**
  ⚠️⚠️⚠️ **REVOGA a premissa "single-user / multi-conta=não / User único" da
  CLAUDE.md.** Releitura: "single-user" significava SEM TIMES/colaboração — NÃO
  "um registro de User só". O app permite **criação de contas**; **vários usuários
  independentes**, cada um na própria bolha. **SEM times, sem compartilhamento, sem
  papéis.**
  - **Isolamento TOTAL por `user_id`:** cada usuário tem seu universo próprio de
    Clients/Projects/Tasks/TimeEntries/Tags/Taggings. ZERO dado compartilhado. Tag
    "maintenance" do user A ≠ "maintenance" do user B (linhas diferentes). Toda query
    de domínio escopa por `Current.user`.
  - **Edge case (a) — entry rodando editável. FECHADA junto:** entry com
    `ended_at IS NULL` é totalmente editável (descrição/projeto/task/tag/billable/
    started_at); `ended_at` só é carimbado no stop. CRUD normal, before_save (Q11/Q16)
    roda igual. Confirmado no tour ao vivo.
  - **Edge case (b) — fuso POR USUÁRIO. FECHADA junto:** `User.time_zone` (string,
    `null: false`, default `"America/Sao_Paulo"`). Todo corte/exibição lê
    `Current.user.time_zone` (Q6/§8 intactas: banco UTC, corte no Ruby via
    `.in_time_zone(...).to_date` — só troca a FONTE do fuso: constante → campo do user).
    UI de edição de fuso: pendente (campo+default agora; telinha de preferências quando
    precisar). Faz sentido genuíno agora que é multi-user.
  - **PROPAGAÇÕES (aplicar quando implementar):**
    1. **Todas as tabelas de domínio ganham `user_id`** (Client, Project, Task,
       TimeEntry, Tag, Tagging) + scoping em TODA query. A tabela da CLAUDE.md NÃO tem
       user_id (assumia user único) → ATUALIZAR.
    2. **Invariante do timer (Q3/Q4) vira POR-USUÁRIO:** "≤1 TimeEntry com ended_at
       NULL **por user**". Índice único parcial (Q4) → `UNIQUE(user_id) WHERE ended_at
       IS NULL`. Rota `current`/`timer` resolve pelo Current.user.
    3. **AccessToken/extensão (Q9–Q17):** já escopa por User (`belongs_to :user`) —
       JÁ CORRETO, só reforça. O token de A nunca vê dado de B.
    4. **Rate/Client/snapshot (Q10/Q11/Q22):** lógica inalterada, só passa a ser
       por-usuário (Client de A invisível pra B).
    5. **Auth:** precisa de SIGNUP (criação de conta) — hoje o magic-code só loga user
       existente. CLAUDE.md não tem signup. → Q24 decide cadastro aberto vs controlado.
  - **PRINCÍPIO (reforça Q22):** multi-USUÁRIO sim (isolamento simples por user_id);
    multi-TIME/colaboração NÃO (é o que "sem times" exclui). A linha "fora de escopo"
    da CLAUDE.md (equipe/compartilhamento/papéis) CONTINUA válida.

- **Q24 — Acesso por CONVITE + admin + landing. FECHADA.** (Não é signup aberto.)
  - **Bootstrap do admin:** no PRIMEIRO acesso ao app, quando NÃO existe nenhuma conta,
    o app cria o **admin geral** (primeiro user = admin). Resolve o ovo-e-galinha do
    convite sem seed manual.
  - **Convite controlado:** o admin CRIA/CONVIDA contas. Sem signup público
    auto-servido — entrar depende do admin te adicionar.
  - **`admin` = BOOLEAN no User** (`User.admin`), NÃO um sistema de roles/permissions.
    É papel OPERACIONAL (administra a instância), não COLABORATIVO. O admin gerencia
    contas/convites/pedidos, mas **NÃO vê dados de domínio alheios** — isolamento Q23
    INTACTO. (Não fere o "sem papéis" da Q23: aquilo era sobre papéis dentro de time.)
  - **Magic-code exige E-MAIL VÁLIDO/entregável** — é identidade E canal. Sem e-mail
    real, sem acesso. (Auth segue passwordless magic-code; só ganha o caminho de
    criação-via-convite além do login de user existente.)
  - **Landing page pública** (fora da área logada) com "**pedir acesso**": coleta
    pedidos; o admin revisa e aprova MANUALMENTE no início (evitar enxurrada de
    signups). Aprovar = cria a conta/convite → dispara magic-link.
  - **`AccessRequest` = ENTIDADE NOVA** (email, name?, note?, status
    pending/approved/rejected, timestamps). FORA do isolamento por user (é pré-conta,
    não pertence a ninguém). Só o admin enxerga. Aprovar cria o User.
  - **RAMO NOVO ABERTO (não grillado ainda):** fluxo de convite (admin cria user →
    e-mail de convite → primeiro login), tela de admin (lista de users + fila de
    AccessRequest + aprovar/recusar), a landing em si (conteúdo/copy/form), e-mail de
    convite vs magic-code normal. Telas de admin são +escopo além do Clockify.

- **Q25 — Privacidade: encryption at rest + admin cego pro domínio. FECHADA.**
  (O Alex perguntou "dá pra criptografar pro admin não ver dados crus dos outros? talvez
  chave enviada ao usuário?". Avaliado o espectro; E2E real REJEITADO por destruir
  relatórios/export server-side + extensão + passwordless. Escolhido o meio-termo são.)
  - **(a) Active Record Encryption (Rails 8 nativo), chave no SERVIDOR** (credentials).
    Protege contra roubo do arquivo SQLite/backup/disco. NÃO protege contra
    operador-com-acesso-ao-servidor — aceito conscientemente. **SEM chave por usuário**
    (a ideia de "chave enviada ao usuário" só faria sentido em E2E, que foi recusado).
  - **(b) Admin CEGO pro domínio — codificado, não só prometido:** a área de admin só
    toca `User` (email/name/admin/status/billing/created_at) + `AccessRequest`. NENHUMA
    rota/tela de admin lê Client/Project/Task/TimeEntry/Tag de outro user. Sem
    "impersonar/ver como" pro domínio. Isolamento Q23 (scoping por user_id) já garante
    no nível de query.
  - **(c) Criptografar:** `description` (mais sensível) + nomes (client/project/task/
    tag), com `deterministic: true` onde precisar de lookup por igualdade. Em CLARO:
    email (índice de login), rate_cents, timestamps, billable (numéricos/operacionais;
    somar exige claro). Conjunto exato de colunas decidido na implementação.
  - **NÃO quebra relatórios (Q18–Q21):** o agrupamento/soma é no RUBY (Q6) — o servidor
    descriptografa ao carregar (tem a chave) e agrupa em memória. AR Encryption só
    atrapalharia LIKE/ordenação/agregação NO BANCO, que não usamos.

- **Q26 — Export do banco (portabilidade / migração entre instâncias). FECHADA.**
  (Alex: "em casos pagos deixar exportar o banco pra usar em outra instância".)
  - **(a)** NUNCA exporta o `.sqlite3` cru (é multi-tenant → vazaria todos os users,
    fere Q23/Q25). Export é **escopado por `user_id`**: só a bolha do usuário (seus
    Clients/Projects/Tasks/TimeEntries/Tags/Taggings + o próprio User).
  - **(b)** Formato = **dump estruturado JSON ou CSVs num zip**, NÃO `.sqlite3` parcial
    (importar SQLite parcial em banco com outros users = conflito de IDs). Precisa de um
    **IMPORTADOR** correspondente (a outra instância cria registros com IDs próprios) —
    export+import é o par que fecha "migrar de instância".
  - **(c)** Sai **em claro**: é o próprio dono autenticado exportando os próprios dados
    (tem direito). A criptografia da Q25 é contra disco/admin, não contra o dono.
  - **(d) GRÁTIS pra todos (NÃO atrás de paywall):** export dos próprios dados é
    **direito de portabilidade** (LGPD/GDPR). Prender atrás de pagamento é má prática e
    contradiz o open source. O paywall (Q27) é sobre ACESSO/USO do app, não sobre levar
    os próprios dados embora. (Revisei a ideia inicial do Alex de amarrar a "pago".)

## Sessão 01/07/2026 — Ramo Auth/convite/admin/landing (Q27–Q38)

> Estado do código no início: só auth existe (User/Session/SignInCode/AccessToken +
> concerns). NENHUMA tabela de domínio, sem admin/time_zone no User, sem landing.
> ⚠️ Bug de design encontrado: `SessionsController#create` faz
> `User.find_or_create_by(email:)` → é signup ABERTO, contradiz a Q24 (convite-only).
> Corrigir na implementação (vira `find_by`).

- **Q27 — Ramo escolhido: Auth/convite/admin/landing.** É o ramo FRESCO (aberto pela
  Q24/Q23, nunca detalhado), BLOQUEIA todo o resto (sem signup/convite + `user_id` nas
  tabelas nenhuma tela de domínio existe correta) e mexe no auth já construído.
  Relatório (detalhes finos), Importador e Timesheet ficam pra depois.

- **Q28 — E-mail DESCONHECIDO no login = resposta EXPLÍCITA + link "pedir acesso".**
  Login vira `find_by` (não `find_or_create_by`). E-mail sem conta → "essa conta não
  existe, peça acesso" + link pra landing/AccessRequest. Vira oráculo de enumeração,
  mas o modelo de ameaça do homelab não se importa (mesmo espírito "sem teatro de
  segurança" do rate-limit). UX > anti-enumeração aqui.

- **Q29 — Convite = REUSAR o magic-code (admin cria User), SEM token de convite.**
  O magic-code JÁ é "prova que controla o e-mail e entra" = exatamente o que um link de
  convite faz. Convite = admin cria o `User` → sistema manda o MESMO magic-code (copy
  de boas-vindas na 1ª vez). Sem `Invitation` token, sem tela de aceite, zero código
  novo de auth. A diferença "convite vs login" é só o TEXTO do e-mail.

- **Q30 — Convite = PULL (não push do código).** E-mail de convite é INFORMATIVO
  ("sua conta existe, entre em `ponto/entrar`"), NÃO carrega código. O magic-code de 6
  dígitos nasce quando o convidado LOGA (fluxo normal). Motivo: o código expira em 15
  min — no push, convite aberto horas depois viraria "código expirado". Pull mantém um
  único gerador de código (o do login) e o convite não carrega segredo (seguro se
  vazar/for encaminhado).

- **Q31 — Estado do convidado = DERIVAR de `sessions`, SEM coluna nova.** "Convidado,
  nunca entrou" = `user.sessions.none?`. Cobre copy de boas-vindas (Q29), status
  pendente/ativo na tela de admin e "reenviar convite" — tudo sem enum `status` nem
  `invited_at`. Segue o princípio "modelo limpo, sem estado especulativo" (Q22/Q23).
  (Suspensão é OUTRA coisa e ganha coluna própria — ver Q34.)

- **Q32 — Ações do admin sobre uma conta = TODAS as quatro.** (Alex marcou tudo, não
  só o corte mínimo que eu recomendei.) Admin faz: **criar/convidar** (Q29/Q30),
  **listar** users (email/name/admin?/já-entrou? via `sessions`), **reenviar convite**
  (pra quem `sessions.none?`), **suspender/reativar** (Q34), **promover/rebaixar admin**,
  **deletar conta com cascade** (Q33). Painel de admin é full-featured. Admin continua
  CEGO pro domínio alheio (Q25b intacta — só toca `User`/`AccessRequest`).

- **Q33 — Deletar conta (cascade + proteções). FECHADA.**
  - **(a) Mecânica:** cascade via `delete_all`/FK `ON DELETE CASCADE` (SQL direto, sem
    callbacks — pra apagar a bolha inteira nenhum callback importa). Leva TUDO da bolha
    (Q23): Clients/Projects/Tasks/TimeEntries/Tags/Taggings + Sessions/SignInCodes/
    AccessTokens.
  - **(b) Proteções (TODAS as 4):** confirmar digitando o e-mail do alvo (padrão
    GitHub) · não pode deletar a si mesmo · não deletar o último admin · oferecer export
    (Q26) antes.
  - **(c) Export antes:** OFERECIDO (link "exportar antes de apagar"), não forçado
    (pode ser conta de teste/spam).

- **Q34 — Suspender/reativar + invariante do último admin. FECHADA.**
  - **(a) Estado:** `User.suspended_at` (datetime nulável, padrão soft-state igual
    `archived_at`/`consumed_at` — Q7). "Suspenso?" = `suspended_at.present?`. SEM enum
    `status` (casa com Q31).
  - **(b) Gate:** no `require_authentication` (concern `Authentication`), DEPOIS de
    resolver sessão/bearer, ANTES de liberar → suspenso vira redirect "conta suspensa"
    (HTML) / 403 (JSON, extensão). Roda a CADA request → sessões vivas do suspenso morrem
    no próximo request (não só no login). ⚠️ **EXCEÇÃO: a rota de export (Q26) é ISENTA
    do gate** — suspenso ainda baixa os próprios dados (portabilidade LGPD/GDPR, igual à
    regra que a cobrança adiada já assumiu).
  - **(c) Invariante geral "≥1 admin não-suspenso":** cobre delete (Q33) + rebaixar +
    suspender — nenhuma dessas ações pode deixar o sistema sem admin ativo.

- **Q35 — Ciclo de vida do `AccessRequest`. FECHADA.**
  - **(a) Aprovar = 1 clique:** cria o `User` (email/name do request) → dispara o
    e-mail de convite informativo (Pull, Q30) → marca `approved`.
  - **(b) Rejeitar = SILENCIOSO** (sem e-mail de "negado"). `rejected` só tira da fila
    do admin. Evita ruído/discussão; no homelab o admin ignora quem não quer.
  - **(c) De-dup por e-mail:** form tolerante, mas se já existe `User` OU `AccessRequest`
    pending com o mesmo e-mail, NÃO cria linha nova (atualiza note/timestamp). Fila não
    polui com re-pedidos.
  - **(d) Resposta do form = genérica** ("recebemos, você será avisado se aprovado") —
    SEM revelar se já tinha conta (aqui anti-enumeração é grátis, ao contrário da Q28).

- **Q36 — Raiz `/` = LANDING pública; app logado em subpath. FECHADA.** `/` serve a
  landing (copy do produto + "pedir acesso" + link discreto "já tenho conta → entrar")
  pra anônimo; redireciona pro app se logado. Padrão SaaS: a "porta da rua" é pública,
  não a tela de login. O login vira link na landing. (Subpath exato do app — `/app` vs
  `/timer` — fica pro ramo de telas de domínio.)

- **Q37 — Bootstrap do 1º admin = via `ADMIN_EMAIL` (env var). FECHADA.** (Alex propôs;
  melhor que minhas 3 opções.) Com banco vazio (`User.none?`), o login normal roda mas
  o `create` só PERMITE criar a conta (e marca `admin: true`) SE o e-mail digitado ==
  `ENV["ADMIN_EMAIL"]`. Qualquer outro e-mail com banco vazio é recusado (Q28).
  Combina prova de posse do e-mail (magic-code normal) + à prova de corrida (o env
  pré-decide QUEM pode ser admin → sem sequestro), sem token extra pra digitar.
  Consequências: **NÃO precisa de rota `/setup` dedicada** (bootstrap = login normal com
  `if User.none?`); `ADMIN_EMAIL` fica inerte depois do 1º admin (promover outros = Q32).

- **Q38 — `ADMIN_EMAIL` ausente + banco vazio = AVISO EXPLÍCITO na tela. FECHADA.**
  Se `User.none? && ADMIN_EMAIL` em branco, a landing/login mostram "Nenhuma conta e
  `ADMIN_EMAIL` não configurado — defina a variável e recarregue". Guia o operador
  (evita beco-sem-saída silencioso que geraria issue no GitHub). NÃO cair no fallback
  "1º a logar vira admin" (reabriria o sequestro que a Q37 fechou).

## Sessão 01/07/2026 (cont.) — Ramo Modelo de dados / telas de domínio (Q39–)

- **Q39 — Ordem de build = CATÁLOGO PRIMEIRO (ordem do brief).** Clients → Projects →
  Tasks → Timer/TimeEntry → Tags → Relatórios. (Alex escolheu; eu recomendei fatia
  vertical timer-primeiro, mas ele preferiu ter os seletores já populados quando o
  timer chegar e construir as invariantes contra catálogo real.) Client é a 1ª tabela.

- **Q40 — Isolamento por user_id (Q23) enforçado via `action_policy` (Action Policy).**
  (Alex escolheu a gem; eu havia recomendado escopo-por-associação sem gem.) Ruby puro,
  SEM Node/asset → não fere a stack. Faz gates por ação (`update?`/`destroy?`) E escopo
  de coleção (`relation_scope` filtra `index`/`find` por tenant). ⚠️ Tensão registrada:
  contraria o espírito "não puxar gem" da Q7 (paranoia) e Q17 (rack-cors) — aceita
  conscientemente porque a Q41 faz a gem carregar a authz inteira (se paga).

- **Q41 — Action Policy = camada de autorização INTEIRA (Forma A). REVISA Q32/Q34.**
  Tudo que é "pode/não pode" vira policy, um lugar só: isolamento por user
  (`relation_scope`), `admin?` do painel (Q32), `suspended?` (Q34), gate de cobrança
  futuro. **Revisão:** os gates que a Q32/Q34 punham no concern `Authentication`
  MIGRAM pra policies. O `require_authentication` ainda resolve QUEM é o user (sessão/
  bearer) e o gate de suspensão pode continuar barrando cedo, mas a decisão canônica de
  autorização (inclusive "export isento" da Q34) é expressa em policy. Manter o
  princípio: sem papéis COLABORATIVOS (Q23) — as policies só expressam tenant +
  admin-operacional + status de conta, não colaboração.

- **Q42 — Currency MORA NO CLIENT (múltiplas moedas reais). Confirma Q11/Q22.**
  (Alex tem clientes em moedas diferentes — BRL e EUR — de verdade.) `Client.currency`
  fica; o form de Client tem seletor de moeda; a rate do Client/Project e o snapshot do
  TimeEntry carregam a moeda do Client. Rejeitada a Forma B (currency por User) porque o
  mix é real. Consequência: reabre o "mix no export" que a Q19a tinha adiado → Q43.

- **Q43 — Mix de moedas: fluxo por-cliente é mono-moeda; visão 'todos' usa subtotais.**
  FATO DO ALEX: **ele fatura POR CLIENTE.** Logo o caminho de faturamento (filtrar por
  cliente → exportar) é SEMPRE mono-moeda por construção — zero fricção, o mix nunca
  entra numa fatura. Regra única: **NUNCA somar moedas diferentes num total.** Na visão
  secundária "todos os clientes" com mix, o total do topo (Q21) vira **subtotais por
  moeda** (BRL: X · EUR: Y), não um número único. SEM aba/arquivo separado, SEM filtro
  de moeda obrigatório, SEM conversão de câmbio (Forma C rejeitada — briga com o
  snapshot imutável Q10/Q11). Fecha a pendência da Q19a: "moeda única por export" vira
  "por-cliente já garante moeda única; visão geral só não soma moedas".

- **Q44 — Nome ÚNICO por usuário, INCLUINDO arquivados. FECHADA.** (Alex escolheu a
  regra mais rígida; eu recomendei "só entre ativos".) `validates :name, uniqueness:
  { scope: :user_id }` SEM condição de `archived_at` → um nome nunca repete, mesmo
  aposentado. Pra reusar, desarquiva o original (é o mesmo cliente, não um novo). Vale
  p/ Client/Project/Tag por `:user_id`; **Task é única por `:project_id`** ("Deploy"
  pode existir em vários projetos). ⚠️ UX (nota p/ build, não é decisão nova): quando o
  create colide com um arquivado, a mensagem deve ser "já existe (arquivado) — desarquivar?"
  em vez de "nome em uso" cru, pra a regra rígida não virar beco sem saída.

- **Q45 — Form do Project mostra a rate herdada como PLACEHOLDER. FECHADA.** (UI do
  modelo da Q22.) Input de rate vem vazio, com texto auxiliar "Herdando do cliente:
  R$ 150 — preencha para sobrescrever". Vazio = herda `client.rate`; digitar = override.
  Caso comum (Q22: quase sempre herda) = não tocar o campo. Projeto SEM cliente (Q2) →
  texto vira "sem cliente → defina uma rate ou fica sem". ⚠️ Detalhe Hotwire: o
  placeholder reflete o cliente SELECIONADO; trocar o dropdown de cliente atualiza o
  valor herdado ao vivo (Stimulus).

- **Q46 — Entry manual aceita início+fim OU início+duração. FECHADA.** (Concretiza a
  Q5, que já previa "início+duração que calcula o fim".) Duração é campo EDITÁVEL:
  digitar "2:30" calcula `ended_at = started_at + duração`. Como o Clockify (tour viu
  duração editável na linha). Schema INTACTO — grava dois timestamps reais (Q5),
  `ended_at > started_at` sempre. Início/fim continuam disponíveis pra quem sabe os
  horários. ⚠️ Padrão Stimulus compartilhado com Q45: **três campos LIGADOS**
  (início/fim/duração) — mexer em dois recalcula o terceiro. Mesmo tipo de "campos
  ligados ao vivo" do placeholder de rate.

- **Q47 — Split E Duplicate ambos no primeiro corte. FECHADA.** (Alex quis os dois; eu
  recomendei adiar Split.) **Duplicate** = re-disparar da Q13 aplicado a entry
  finalizado (copia descrição/projeto/task/tags, horários novos) — custo ~zero.
  **Split** = quebrar um entry em dois (entra, mas ganha regras próprias na Q48). Delete
  já é o CRUD normal. Menu ⋮ do entry = Split · Duplicate · Delete (paridade com o tour).

- **Q48 — Split: mecânica. FECHADA.**
  - **(a)** A segunda metade (B) nasce **cópia FIEL de A** (mesma descrição/projeto/
    task/tags/billable); você edita B na lista depois pra trocar o que mudou. NÃO
    adivinha o novo projeto, NÃO abre form na hora.
  - **(b)** Cada metade é TimeEntry próprio → cada uma **re-resolve e congela seu
    snapshot** de rate no `before_save` (Q11). Trocar o projeto de B re-snapshota só B;
    A mantém o original.
  - **(c)** Ponto de corte **estritamente entre** started_at e ended_at (nunca nas
    bordas → evita duração-zero da Q15c); só em entry **finalizado** (não no timer
    rodando); **transação** atômica (cria B + encurta o ended_at de A).
  - **(d)** Split PODE cruzar a meia-noite — é manual/explícito (você escolheu cortar),
    diferente do fatiamento AUTOMÁTICO que a Q6 rejeitou. Cada metade cai no dia do seu
    próprio started_at → coerente com Q6, não conflita.

- **Q49 — Edição INLINE por linha (Turbo Frame). FECHADA.** (Concretiza a descoberta
  do tour: editar é inline na lista, não tela separada.)
  - **(a)** Cada entry = `turbo_frame_tag "time_entry_#{id}"` que troca exibição↔edição
    sem recarregar a lista. Padrão Hotwire canônico; casa com o `respond_to` da Q9
    (JSON p/ extensão, HTML/Turbo p/ web).
  - **(b)** Uma edição por vez (recomendado, NÃO forçado — frames são independentes,
    abrir duas é possível, só não incentivado).
  - **(c)** O entry RODANDO (topo, `ended_at` nulo) edita no MESMO frame:
    descrição/projeto/task/tag/billable/início livres (Q23a), mas **fim/duração
    READ-ONLY enquanto roda** — só o stop carimba `ended_at` (Q14). Editar NÃO pára o
    timer (preserva invariante Q3/Q4/Q14).
  - **(d)** Duração ao vivo da linha do timer = **Stimulus controller client-side**
    (cronômetro visual). NÃO Turbo Stream por segundo (martelaria o servidor). Servidor
    continua fonte da verdade no stop.

- **Q50 — Seletor de projeto/task SÓ SELECIONA (sem inline-create). FECHADA.**
  Estrutura de exibição (tour): **"(sem projeto)" no topo** (Q15) + projetos AGRUPADOS
  POR CLIENTE (com balde "(sem cliente)", Q2) + tasks aninhadas sob o projeto. Criar
  Project/Task = só na tela de CRUD (Q39) → **um caminho de criação**, validações/rate
  (Q44/Q22) num lugar só. Motivo de recusar inline-create: criaria Project "pela metade"
  (sem cliente/rate/cor) sujando o CAMINHO DO DINHEIRO; e o fluxo do Alex é configurar
  catálogo com calma ANTES (por isso "catálogo primeiro", Q39), não criar caótico no
  meio. Inline-create de Project fica como enriquecimento FUTURO.

- **Q51 — Tag CRIA INLINE no seletor de tagging (≠ Project da Q50). FECHADA.**
  Inconsistência PROPOSITAL e justificada: Tag nasce COMPLETA (só nome + user_id, sem
  rate/cliente/cor → nada "pela metade" a evitar) e o uso é AD-HOC no lançamento
  ("marca como 'urgente'"). Logo o seletor de tags permite "Criar tag 'X'" inline.
  Project protege o caminho do dinheiro → só-na-tela; Tag não tem esse caminho → inline
  OK. Seletor = multi-select (chips, M:N Q8), mostra só ativas + as que o entry já tem
  (Q8). Tela de Tags (Q8) existe pra GERENCIAR (renomear/arquivar); CRIAR pode ser inline.
  ⚠️ Regra geral de inline-create derivada: **cria inline quem nasce completo e é usado
  ad-hoc (Tag); só-na-tela quem tem caminho do dinheiro / nasce incompleto (Project).**

- **Cobrança $1/mês — ADIADA (NÃO grillada). Esboço só pra não perder o raciocínio:**
  - Construir POR ÚLTIMO, "quando houver gente pedindo acesso" (palavras do Alex). Não
    pôr billing antes do app funcionar.
  - Esboço de desenho (a confirmar quando for a hora): **Stripe** (Checkout +
    Subscriptions — não processar cartão direto, regra de ouro PCI). App NÃO guarda
    cartão; guarda no User `subscription_status` (active/past_due/canceled/none) +
    `stripe_customer_id` (+ `current_period_end`?). Fonte da verdade = Stripe; app reage
    a **webhooks**. Gate de acesso = **convidado (Q24) E assinatura ativa**. Lapso
    (past_due/canceled) → **bloqueia acesso mas NUNCA apaga dados**, e o **export (Q26)
    continua acessível** (portabilidade não depende de pagar).
  - Detalhes NÃO decididos (dependem de volume/origem dos users): trial?, reembolso?,
    múltiplas moedas?, dunning?. Há skills Stripe disponíveis no harness pra quando for.

## Sessão 02/07/2026 — Fecho do Modelo de dados (Q52) + Ramo Relatório/Export (Q53–)

- **Q52 — Cor do Project = PALETA FIXA curada. FECHADA.** (Fecha o ramo Modelo de dados.)
  - ~12 cores escolhidas a dedo (estética retrô), UI = grid de swatches (radio buttons
    estilizados, zero JS). SEM picker livre, SEM opção custom (enriquecimento futuro
    se alguém pedir).
  - **Auto-atribuição no create:** pré-seleciona a cor MENOS USADA entre os projetos
    ativos do user → donut (Q21) sem fatias repetidas sem o usuário pensar nisso.
  - **Schema:** `color` string hex `#RRGGBB`, `null: false`. Validação de FORMATO no
    model (não inclusão na paleta) → a paleta pode evoluir sem invalidar dado antigo;
    a paleta é restrição de UI (o form só oferece os swatches).
  - Motivo: donut legível (contraste garantido entre fatias) + identidade retrô
    preservada + mais barato que estilizar `<input type="color">` (feio, varia por OS).

- **Q53 — Seletor de período = presets ENXUTOS + setas ‹› + custom. FECHADA.**
  - **Presets:** Hoje · Esta semana · Este mês · Este ano · Personalizado (2 date
    inputs). Os "passados" (ontem, semana/mês/ano passado) saem via seta ‹ — presets
    que duplicam as setas são UI parada (cortados os 9 do Clockify).
  - **Setas ‹ ›** andam pelo TAMANHO do período ativo (mês→mês, semana→semana; custom
    → mesmo nº de dias). **Default ao abrir = "Este mês"** (ciclo de faturamento; o
    export mensal é o entregável principal).
  - **Semana começa SEGUNDA, fixo** (sem config — início de semana configurável é
    coisa de produto multi-mercado).
  - **Bordas no fuso do user (Q23b):** período = [1º dia 00:00, último dia 23:59:59]
    em `Current.user.time_zone`, comparado contra `started_at` (Q6: entry pertence
    inteiro ao dia do started_at). O período alimenta Summary, Detailed E o export.

- **Q54 — Filtros finos = 6 dimensões, OR dentro / AND entre. FECHADA.**
  - **Filtros:** Client · Project · Task · Tag (multi-select, com baldes "(sem X)"
    filtráveis — Q2/Q15) + **Billable** (todos / só faturável / só não-faturável —
    substituto útil do "Status" do Clockify, que é approval de equipe e está fora) +
    **Description** (busca contains, case-insensitive).
  - **Semântica:** OR dentro da dimensão (projeto A ou B), AND entre dimensões.
    Padrão facetado do Clockify/qualquer relatório.
  - **Opções listadas = o que existe no período** (Q8), não o catálogo ativo.
  - ⚠️ **Description roda em RUBY** (consequência Q25: coluna criptografada → LIKE no
    banco não funciona). Período (timestamps em claro) restringe primeiro no SQL;
    filtros de ID (client/project/task/tag) também vão no SQL; contains de descrição
    filtra em memória. Insumo pro contrato de queries.

- **Q55 — View Weekly = CORTADA. FECHADA.** Relatório tem DUAS abas: **Summary ·
  Detailed** (como a CLAUDE.md já dizia). A grade projeto × dia da semana do Clockify
  é a mesma informação do Summary com período "Esta semana", pivotada — e brilha em
  contexto de EQUIPE (linhas por pessoa), dimensão que cortamos (Q23). Se sentir
  falta: é uma pivot barata sobre a query de "horas por dia por grupo" que o gráfico
  de barras do Summary já vai usar (sem schema/query nova). Não confundir com o
  **Timesheet** (grade semanal de ENTRADA de dados) — esse ainda é um "talvez" a
  decidir no fim do ramo.

- **Q56 — Rounding: POR ENTRY, blocos 5/15/30, 3 direções. FECHADA.** (Paga a dívida
  da Q11, que fechou "toggle existe" e adiou os detalhes.)
  - **Granularidade: POR ENTRY** (fixo). Arredondar total de grupo faria Detailed não
    bater com Summary/export; por entry, tudo soma consistente em qualquer group-by.
    (= Clockify.)
  - **Bloco:** 5 / 15 / 30 min, default **15**. **Direção:** pra cima / mais próximo /
    pra baixo, default **mais próximo** (as 3 custam o mesmo select).
  - **Só LEITURA:** recalcula duração exibida + amount (`horas_arredondadas × rate`,
    centavo ROUND_HALF_UP no fim — Q11/Q19) no relatório/export. NUNCA toca
    started_at/ended_at/snapshot gravados (Q10/Q11 intactas).
  - **Config em params do relatório** (URL, viaja pro export), **OFF por padrão**.
    Persistir como preferência do user: só quando existir a tela de preferências
    (Q23b) — sem coluna nova agora (feature que o Alex nem usa hoje; xlsx real é exato).

- **Q57 — Entry RODANDO fica FORA do relatório/export. FECHADA.** Relatório e export
  só enxergam `ended_at IS NOT NULL` (sessões finalizadas, sempre com os dois
  timestamps — Q5). Papéis: **tracker = presente** (mostra o rodando com cronômetro
  ao vivo — Q49d); **relatório/export = passado consolidado** (número estável,
  artefato arquivável — Q10). Zero caso especial de "duração parcial" no pipeline
  (rounding Q56 / amount Q18 só processam entry completo). O buraco ("Hoje" subconta
  enquanto roda) é aceito — o export mensal se gera com mês fechado.

- **Q58 — Contrato das queries = PORO `Report` (1 query SQL + pipeline Ruby). FECHADA.
  🏁 FECHA O RAMO RELATÓRIO/EXPORT.** Encryption (Q25) + fuso por user (Q6/Q23b) já
  matavam GROUP BY/LIKE no banco — o contrato oficializa:
  - **1 query SQL:** `Current.user.time_entries` finalizados (Q57)
    `.where(started_at: range-no-fuso)` (Q53) + filtros por ID (project/task IN com
    `IS NULL` pros baldes; client via join em projects; tag via EXISTS em taggings;
    billable) (Q54) + `includes(:task, :tags, project: :client)` contra N+1.
  - **Pipeline Ruby** (decrypt no load): Description contains (Q54) → rounding
    opcional por entry (Q56) → corte do dia no fuso (Q6) → agrupamento 1–2 níveis
    (Q21) → totais (tempo, tempo billable, amounts POR MOEDA — Q43) → série diária
    (barras) + fatias do donut.
  - **Onde vive:** `app/models/report.rb` — `Report.new(user:, period:, filters:,
    group_by:, rounding:)` expõe `groups`/`rows`/`totals`/`daily_series`. Modelo rico
    vanilla, SEM service layer (STYLE.md). Controller fino monta o Report dos params.
  - **Uma estrutura, três consumidores:** Summary (groups), Detailed (rows,
    `started_at` DESC, SEM paginação no 1º corte — volume single-user), export
    xlsx/CSV da MESMA matriz (Q20). Tela e export sempre batem por construção.
  - Volume em memória OK: um ano de entries ≈ milhares de linhas, trivial.

- **Q59 — Timesheet = CORTADO DE VEZ (sai do "talvez"). FECHADA.** Vai pra lista
  "fora de escopo" da CLAUDE.md. Motivo de MODELO, não só de escopo: a grade semanal
  é entrada por DURAÇÃO PURA ("8h na terça", sem início/fim reais) — exatamente o que
  a **Q5 rejeitou**. Suportar exigiria inventar timestamps fake ou revogar a Q5,
  sujando o que corte-de-dia (Q6), split (Q48) e report (Q58) assumem. Público-alvo é
  outro (preenchimento em lote); nosso fluxo é timer-driven + entry manual (Q46). Se
  um dia mudar, a decisão a revogar conscientemente é a Q5, não "adicionar uma tela".

- **Q60 — Calendar e Dashboard = CORTADOS (abre o ramo TELAS). FECHADA.** O brief
  (PDF) só os cita na lista da sidebar (TELA 04) — nunca ganharam bloco
  MANTER/REMOVER próprio; entraram de carona no print do Clockify. **Dashboard**
  duplica o Reports Summary (que já abre em "Este mês" com barras/donut/totais —
  Q53/Q21). **Calendar** é a tela mais cara do catálogo (drag pra criar/redimensionar
  blocos = JS pesado que briga com "Hotwire, não JS avulso") pra um fluxo que não
  agenda entries. Diferente do Timesheet (Q59), NÃO há conflito de modelo — podem
  voltar um dia como enriquecimento, sem revogar nada. **Sidebar final: Tracker
  (home) · Reports · Projects · Clients · Tags** + Admin (só p/ admin) + Preferências
  (Q23b). ⚠️ ATUALIZAR a CLAUDE.md (sidebar lista Calendar/Dashboard).

- **Q61 — URLs: resources no topo, home = `time_entries#index`. FECHADA.** (Paga a
  pendência da Q36 "subpath do app".)
  - `/` = landing (anônimo) ou redirect pro tracker (logado). Home do logado =
    **`/time_entries`** (o tracker: timer no topo + lista) — "Tracker" é rótulo de
    UI na sidebar, não URL especial.
  - **SEM namespace `/app`** e SEM rota-vaidade `/tracker`: o contrato Q9/Q13 já fixou
    `/timer` e `resources :time_entries` sem prefixo (extensão usa as MESMAS rotas;
    `time_entries#index` serve HTML pra web E JSON pra "lista recente" da extensão).
  - Demais recursos no topo: `/reports`, `/clients`, `/projects` (tasks aninhadas),
    `/tags`, `/preferences`. **Admin em namespace `/admin`** próprio (área realmente
    separada — Q32).

- **Q62 — CSS = custom properties ZERO-BUILD (estilo fizzy). FECHADA.** (Mata o
  "a definir" da CLAUDE.md/brief.) CSS puro: tokens em `:root` (paleta Q52 vira
  `--color-*`, cinzas retrô, espaçamentos), arquivos por componente, servido pelo
  Propshaft — editar e dar refresh, sem build/binário/watch. Motivos: (1) retrô 90s
  = bevels/bordas/fontes CUSTOM que utilities do Tailwind não cobrem — escreveríamos
  CSS na mão de qualquer jeito; (2) Tailwind standalone não fere a regra do Node mas
  reintroduz build step + binário versionado + purge; (3) fizzy (referência declarada)
  usa exatamente esse padrão — o que estudarmos lá cola direto. ⚠️ ATUALIZAR CLAUDE.md.

- **Q63 — Estética = MODERNA, minimal densa (estilo Linear). FECHADA.
  ⚠️⚠️ REVOGA o "retrô anos 90" da CLAUDE.md/brief** (Alex: "não quero layout retro,
  quero um layout moderno"). Decidida após pesquisa de práticas 2025/26 (Linear como
  referência dominante em ferramenta de produtividade).
  - **Direção:** base neutra quase-branca, UM acento, linhas densas escaneáveis SEM
    cards/bordas por linha, sidebar quieta (texto puro), hierarquia feita por
    tipografia/peso/espaço — não por chrome. **Personalidade = cores dos projetos
    (Q52)** pontuando a UI; **elemento-assinatura = a barra do timer** (único ponto
    visualmente forte da tela).
  - **Práticas adotadas junto (valem pra TODA tela):** design tokens semânticos nas
    custom properties (Q62); `font-variant-numeric: tabular-nums` em coluna de
    duração/dinheiro; progressive disclosure (filtros/poderes recolhidos até
    precisar); piso de acessibilidade (contraste, foco visível,
    `prefers-reduced-motion`); responsivo até mobile (PWA).
  - Rejeitadas: Win95/GeoCities/terminal (retrô), Toggl-arejado (menos denso),
    dark-first. ⚠️ ATUALIZAR CLAUDE.md ("Estética alvo: retrô anos 90" → moderna
    minimal densa).

- **Q64 — Dark mode AUTOMÁTICO já na v1 (prefers-color-scheme). FECHADA.** (Alex
  escolheu ir além da minha recomendação de "claro-somente dark-ready".)
  - Claro + escuro desde o início, trocando pelo **OS** (`@media
    (prefers-color-scheme: dark)`). **SEM toggle manual, SEM preferência por user**
    (nada de coluna nova; se auto-detecção incomodar um dia, aí sim vira preferência).
  - **Consequências aceitas:** (1) tokens da Q62 OBRIGATORIAMENTE semânticos
    (`--surface`/`--text`/`--accent`…) com valores nos DOIS temas; (2) a **paleta Q52
    precisa funcionar sobre fundo claro E escuro** (curadoria com contraste duplo —
    donut, bolinhas, barra do timer); (3) QA visual de toda tela nos dois temas.

- **Q65 — Mobile (PWA) = BOTTOM TAB BAR; desktop = sidebar (Q63). FECHADA.** (Alex
  escolheu tabs; eu recomendei drawer.) Navegação mobile de 1 toque, ergonomia de
  app nativo — aceito o custo de manter uma SEGUNDA estrutura de navegação em
  paridade com a sidebar. **Barra do timer segue no TOPO também no mobile** (ação
  principal + assinatura visual, nunca atrás de menu). Composição das tabs: ver Q65b.

- **Q65b — Tabs = Tracker · Reports · Projects · Mais. FECHADA.** "Mais" abre lista
  simples: Clients · Tags · Preferências · Admin (se admin). Critério: tab pro que é
  DIÁRIO (Tracker/Reports/Projects); catálogo raro (Clients/Tags — configura uma vez,
  Q39/Q50) e conta ficam a 2 toques. **No desktop:** sidebar com os 5 itens de
  trabalho + **Preferências/Admin no RODAPÉ da sidebar** (não são navegação de
  trabalho).

- **Q66 — Preferências = 3 seções. FECHADA.** (`/preferences` — Q61.)
  - **Perfil:** `name` editável · e-mail READ-ONLY (trocar e-mail = trocar identidade
    de login no passwordless; fluxo sensível, fora do 1º corte) · `time_zone` select
    (paga a pendência da Q23b).
  - **Extensão/API:** AccessTokens — listar (label · read/write · último uso),
    criar (label + permissão → mostra token pra copiar), revogar. Schema já suporta
    (label/permission/last_used_at já existem).
  - **Meus dados:** botão do export Q26 (zip da bolha). É a rota isenta do gate de
    suspensão (Q34b).
  - **Fora:** tema (Q64 é automático via OS), deletar a própria conta (admin faz —
    Q33), gestão de sessões ativas (enriquecimento futuro).

- **Q67 — Landing = UMA DOBRA. FECHADA.** (Paga o "copy/layout da landing" das
  Q24/Q36/Q38.) Nome + uma frase honesta ("time tracker enxuto e self-hosted: timer,
  projetos, relatório mensal") + form "pedir acesso" inline (email/name?/note? — Q35,
  resposta genérica Q35d) + link discreto "já tenho conta → entrar" + rodapé com link
  do GitHub (open source). Copy em PORTUGUÊS (padrão da UI). Estado Q38 (banco vazio
  sem `ADMIN_EMAIL`) SUBSTITUI o form pelo aviso ao operador. SEM seções de
  marketing/features/screenshots — o público real é fila de convite manual +
  self-hoster (que avalia pelo README; "landing de produto" de verdade é o README).
  Bônus: primeira tela a exercitar os tokens claro/escuro (Q62/Q63/Q64).

- **Q68 — Admin = PÁGINA ÚNICA `/admin`. FECHADA.** (Paga o "layout do painel" da
  Q32.) Duas seções: **fila de AccessRequests pendentes no TOPO** (só renderiza
  quando há pendentes — é o que exige ação; aprovar/rejeitar via Turbo, a fila
  atualiza inline) + **tabela de users** (email · name · admin? · status
  convidado/ativo via sessions Q31 · suspenso Q34) com ações no menu ⋮ por linha
  (reenviar convite, suspender/reativar, promover/rebaixar, deletar → confirmação
  digitando o e-mail Q33b) + botão "convidar". Por baixo, DOIS resources REST
  (`admin/users`, `admin/access_requests`) — só a view do index é compartilhada.
  Racional: volume homelab (dezenas de users, fila quase sempre vazia) não justifica
  área multi-página; otimizar pra "entrei, resolvi, saí".

- **Q69 — PWA: SW COM PÁGINA OFFLINE ESTÁTICA. FECHADA.** (Alex escolheu um degrau
  acima da minha rec de SW no-op.) Estado atual: manifest/SW são defaults do Rails 8
  (`theme_color: "red"` placeholder, SW todo comentado).
  - **Service worker:** cacheia UMA página offline estática ("você está offline",
    com a cara do app/tokens) no install; fetch handler só pra NAVEGAÇÕES: network
    primeiro, catch → página offline. NADA além disso em cache (dados/assets/shell
    NÃO — online-only da CLAUDE.md intacto). Versionar o cache pelo nome (bump manual
    ao mudar a página).
  - **Implementação a fazer junto:** manifest com cores dos tokens (Q62/Q64 —
    theme/background por tema), `start_url: "/"` (redirect Q61 resolve), ícone REAL
    do Ponto (o atual é o genérico do Rails; desenhar na direção Q63).
  - **Web Push = FORA** (anotado como enriquecimento futuro: lembrete "timer
    rodando há 8h" — custaria VAPID + subscriptions + UI de permissão).

- **Q70 — Tipografia = INTER VARIABLE self-hosted. FECHADA.** Um woff2 (~100 KB) em
  `app/assets` (self-hosted = zero build, zero Node — restrição intacta), pesos
  variáveis fazem a hierarquia (Q63: tipografia carrega tudo, sem cards/bordas),
  `font-variant-numeric: tabular-nums` nas colunas de duração/dinheiro. É a fonte do
  Linear — o acabamento da direção Q63; a personalidade fica com as cores de projeto
  + barra do timer. Rejeitadas: system stack (voz varia por OS), dupla com display
  (app denso tem pouca superfície de título — risco de enfeite).

- **Q71 — Gráficos = SVG SERVER-RENDERED (partials ERB). FECHADA.
  🏁 FECHA O RAMO TELAS.** Barras por dia e donut (Q21) são geometria trivial
  (retângulos; arcos com `stroke-dasharray`); partials ERB recebem
  `daily_series`/`groups` do `Report` (Q58) e cospem `<svg>`. **Zero JS**, estilo
  100% nos tokens CSS (dark Q64 de graça, cores de projeto Q52 direto), atualiza via
  Turbo como HTML qualquer. Hover simples via `<title>`/CSS. Rejeitados: Chart.js
  (~200 KB pra 2 gráficos estáticos, tema em JS fora dos tokens, dança
  Stimulus↔Turbo) e CSS puro (donut em conic-gradient é gambiarra). Interatividade
  de clique-na-fatia NÃO está no escopo (filtro é a linha de filtros — Q54).

- **Q72 — Importador = JSON único versionado + import SÓ em bolha vazia. FECHADA.
  🏁 FECHA O RAMO IMPORTADOR — GRILLING COMPLETO.** (Resolve o "JSON ou CSVs num
  zip" que a Q26b deixou em aberto.)
  - **Formato do export:** UM arquivo `ponto-export-YYYY-MM-DD.json` com
    `schema_version: 1` + um array por entidade (User + Clients/Projects/Tasks/Tags/
    TimeEntries/Taggings), **IDs originais preservados como referências internas**.
    Sem zip (alguns MB no pior caso). Dump é pra MÁQUINA — leitura humana já é o
    export de relatório (Q20).
  - **Import só em bolha VAZIA** (zero registros de domínio): o caso de uso é
    MIGRAÇÃO de instância, não merge. Rejeitado merge-por-nome (matriz de conflitos
    da Q44 por um cenário que não é o alvo).
  - **Remapeamento:** destino cria IDs próprios, refaz FKs na ordem Client → Project
    → Task → Tag → TimeEntry → Tagging. **Snapshots rate/currency entram COMO ESTÃO**
    (Q10 — histórico congelado; o `before_save` de re-snapshot NÃO roda no import).
  - **UI:** Preferências → "Meus dados" (Q66), botão de import ao lado do export,
    visível só com bolha vazia.

## Sessão 02/07/2026 (cont.) — Ramo CLI (Q73–), aberto pelo Alex após o fecho

> Motivação: "usar o app por CLI, como o fizzy" — pra usar via Claude, ferramentas
> GUI e clients desktop. Referência `~/Projetos/fizzy-cli`: binário Go, **MIT**
> (pode copiar/adaptar!), envelope JSON {ok,data,summary,breadcrumbs}, --jq
> embutido, profiles em ~/.config/fizzy/, skill/plugin pro Claude, doctor. Lado
> Rails do fizzy: mesmas rotas + respond_to + views .json.jbuilder (= nosso Q9).

- **Q77 — Landing = DE PRODUTO (vender). ⚠️ REVOGA a Q67 ("uma dobra").** (Alex,
  02/07, vendo a landing mínima no ar: "quero uma landing de produto, que mostre o
  que o app faz, que convença alguém que não usa a usar. fale sobre a extension,
  sobre a cli, screenshots, tem que vender".) Nova forma: hero com pitch + CTA →
  seções de features (timer 1-clique · extensão Chrome · CLI/agents · relatórios ·
  export xlsx/CSV · privacidade/encryption · open source/self-hosted multi-user
  isolado) + "screenshots" como MOCKUPS HTML/CSS theme-aware (o app real mal existe;
  mockups em HTML puro seguem os tokens claro/escuro e evoluem com as telas reais) +
  form "pedir acesso" continua sendo o CTA + rodapé GitHub. SEM pricing (cobrança
  $1/mês segue ADIADA — não prometer preço). Estado Q38 (aviso de operador) e o
  contrato do form/AccessRequest (Q35) INTACTOS. Copy vendedora mas sem claim falso
  ("disponível na Web Store" etc. — extensão/CLI são produto DESENHADO, sinalizar
  "em breve" onde ainda não shipped). **+ Adendo do Alex na mesma hora:** a landing
  também (a) FALA DA TECNOLOGIA (Rails 8 + Hotwire + SQLite, zero Node, backup = um
  arquivo — a stack é argumento de venda pro público self-hoster) e (b) EXPLICA COMO
  SELF-HOSTAR (seção passo-a-passo honesta: clone → deploy Docker/Kamal → `ADMIN_EMAIL`
  + SMTP → primeiro login vira admin; apontando pro README como guia completo).

- **Q79 — i18n pt-BR/EN na LANDING. FECHADA.** (Alex, 02/07: "precisa de i18n,
  essa landing precisa ser português/inglês, bandeirinha pra trocar, default pega
  o browser".) Escopo: a LANDING (não o app inteiro — UI interna segue português
  por ora; expandir depois se precisar). Mecânica: Rails I18n com
  `config/locales/{pt-BR,en}.yml`; **default = `Accept-Language` do browser**;
  **seletor com bandeirinhas** (🇧🇷/🇺🇸) na landing troca via `?locale=` +
  persistência em sessão. A copy PT canônica é a do copy-pass de 02/07 (revisão do
  Alex: "o português estava terrível" — corrigido coloquialismo/anglicismo).

- **Q77b — PREÇO PÚBLICO NA LANDING: "Ponto Cloud, US$ 1/mês". ADENDO à Q77.**
  (Alex: "o pedir acesso tem que ficar claro que é pra minha instância — não quer
  hospedar? use o ponto cloud apenas $1/mês".) A landing nomeia a instância
  hospedada de **Ponto Cloud** e anuncia **US$ 1/mês** no CTA (hero + seção final),
  deixando claro o par de caminhos: self-host (GitHub) vs Cloud (pedir acesso).
  ⚠️ NOTA HONESTA: a COBRANÇA em si continua ADIADA/não construída (💤) — anunciar
  o preço é seguro porque a aprovação é MANUAL (o admin controla quem entra e a
  expectativa criada). Construir billing antes de aprovar volume.

- **Q80 — ÍCONES = LUCIDE, vendorizados como SVG inline. FECHADA.** (Alex, 02/07:
  "use os ícones lucide no app onde fizer sentido".) Mecânica: **vendorizar só os
  SVGs usados** (~15–20 ícones, licença ISC) como partials/arquivos + helper `icon`
  pequeno — SVG inline com `currentColor` (segue os tokens claro/escuro de graça),
  `aria-hidden` por padrão, tamanho por CSS. **SEM gem** (lucide-rails desatualiza
  vs upstream; espírito Q7/Q17 de não puxar gem pra coisa trivial), **SEM JS** (o
  pacote lucide.js é pra SPA — nosso uso é estático). Onde faz sentido: sidebar +
  bottom tabs (ícone+label — mobile especialmente), menus ⋮ (more-vertical), ações
  (archive/pencil/trash/plus/search), play/square pro timer (Fase 3), admin
  (aprovar/recusar/suspender), estados vazios. Onde NÃO: landing (identidade
  própria, review visual do Alex), texto corrido. Critério: ícone SEMPRE acompanha
  label (Q63: hierarquia por tipografia; ícone é apoio, não substituto) exceto em
  botões compactos com aria-label.

- **Q78 — LICENÇA = O'Saasy (a mesma do fizzy). FECHADA.** (Alex, 02/07: "quero a
  mesma licença do fizzy. a pessoa não pode fazer um SaaS com o Ponto".)
  - **App Ponto**: licença **O'Saasy** — MIT-like + cláusula 2: proibido oferecer o
    software (ou derivado) a terceiros como SaaS/hosted/managed onde o valor primário
    é a funcionalidade do próprio software. Self-host pessoal/empresa interna: livre.
    `LICENSE.md` na raiz, copyright © 2026 Alex Takitani (texto adaptado do
    `~/Projetos/fizzy/LICENSE.md`).
  - **ponto-cli continua MIT** (Q74 intacta — é fork do fizzy-cli, que é MIT; mesma
    combinação do próprio fizzy: app O'Saasy + CLI MIT).
  - **Consequência de copy**: "open source" nos textos (landing/CLAUDE.md/README)
    vira "**código aberto (licença O'Saasy)**" — source-available, não OSI; a landing
    diz honestamente "self-hoste à vontade; proibido revender como SaaS".
  - Aplicar na INTEGRAÇÃO: LICENSE.md + ajuste de copy na landing + linha na CLAUDE.md.

- **Q73 — Superfície JSON TOTAL no app. FECHADA.** (Amplia a Q9, que pensava só na
  extensão.) TODO resource de domínio responde JSON via `respond_to` + view
  `.json.jbuilder` nas MESMAS rotas: **catálogo (Clients/Projects/Tasks/Tags) +
  timer + time_entries + report + export**. Regras: escalares no JSON (`rate_cents`
  int + `currency` string, NUNCA Money cru — Q11); invariantes idênticas (409 do
  timer — Q14); **erros padronizados** (`{error:}` + status HTTP correto) em toda
  rota JSON. **FORA da superfície:** auth de browser (magic-code é fluxo humano),
  admin (operacional, só-web — rejeitada a opção "total + admin": expõe ação
  sensível a token por um caso raro), import (upload raro, só-web). Export ENTRA
  (baixar xlsx/CSV por CLI é útil). Implementar o `format.json` JUNTO com cada
  controller ao construir (barato agora, retrofit caro).

- **Q74 — CLI = GO, FORK ESTRUTURAL DO FIZZY-CLI, repo separado `ponto-cli`. FECHADA.**
  Racional: fizzy-cli é **MIT** → adaptar (não só estudar): troca-se domínio e marca,
  **herda-se a infraestrutura pronta** — single binary multi-plataforma (goreleaser +
  installer), envelope JSON `{ok, data, summary, breadcrumbs}`, `--jq` embutido,
  `--styled`/`--markdown`, precedência de config (flags > env > profile > local >
  global), doctor, help agent-first (`--help --agent`, `commands --json`), skill/
  plugin Claude. Aceito o custo da segunda linguagem (Go) — repo separado, padrões
  prontos, manutenção Alex+Claude. Repo separado também isola licença (ponto-cli
  pode ser MIT) e ciclo de release. Rejeitados: Ruby gem/Thor (exige runtime, sem
  binário único, reescreve o pronto) e wrapper bash (aquém do padrão fizzy pedido).
  Auth do CLI = o `AccessToken` que já existe (bearer read/write — Q73).

- **Q75 — CLI nasce INCREMENTAL, logo após a fatia Timer/TimeEntry. FECHADA.**
  Primeiro corte de comandos = o que a API já tem nesse ponto: `timer start/stop/
  status` · `entry list/show/create/update/delete` · catálogo `client`/`project`/
  `task`/`tag` (list/show/create/update/archive/unarchive). `report`/`export`
  chegam quando o app os tiver (fim da ordem Q39). Infra (setup/doctor/commands/
  skill) vem do fork em qualquer cenário. Racional: o valor pedido é "trackear pelo
  Claude" — dogfood do Ponto via CLI durante o resto do build; a API core (timer/
  invariantes) já estará estável. Rejeitados: big bang pós-export (benefício tarde
  demais) e timer-only (sem catálogo não seleciona projeto direito).

- **Q76 — Config/integração = HERDA o fizzy-cli com 4 adaptações self-hosted.
  FECHADA. 🏁 FECHA O RAMO CLI — GRILLING COMPLETO DE NOVO (Q1–Q76).**
  - **Herda:** precedência flags > env > profile > config local > global; token em
    keyring com fallback em arquivo; `setup` interativo; `doctor`; help agent-first;
    envelope/--jq (Q74).
  - **Adaptações:** (1) **`api_url` OBRIGATÓRIA** no setup — self-hosted, sem URL
    default (≠ fizzy.do); (2) **profiles** `prod` (homelab) / `dev` (localhost) +
    env `PONTO_TOKEN`/`PONTO_API_URL`/`PONTO_PROFILE`; (3) **skill embarcada +
    `ponto setup claude`** (o caminho do "usar no Claude"; plugin de marketplace
    fica pra quando for público); (4) **default project OPCIONAL** no perfil
    (`timer start` sem `--project` usa o default — conveniência, não pré-requisito,
    igual Q15b/extensão).
  - Token é o MESMO `AccessToken` da extensão, gerado na MESMA tela (Preferências →
    Extensão/API — Q66; renomear a seção pra "Extensão & CLI" na implementação).

## DESCOBERTAS DO TOUR AO VIVO (Clockify, 30/06) — confirmam/abrem decisões
- ✅ **Timer rodando É EDITÁVEL** (cliquei no projeto da barra ativa → abriu seletor).
  Resolve o edge case "editar entry rodando": SIM, permitido (descrição/projeto/tag/
  billable enquanto roda). → fechar formalmente na Q de edge cases.
- ✅ **Edição é INLINE na lista** (não tela separada): clicar na linha vira inputs
  (descrição, início, fim, duração). Menu ⋮ por entry = **Split · Duplicate · Delete**.
  → pro front Hotwire: Turbo Frame por linha. Split/Duplicate = extras (avaliar no mínimo).
- ✅ **Seletor de projeto** = "No Project" no topo + projetos AGRUPADOS POR CLIENTE
  ("NO CLIENT → exato", "SAMUEL → Kube, LaKube") + Create Task/Project inline. Confirma
  Q2/Q15.
- ✅ **Lista do tracker** agrupada por dia, com Total/dia e Total/semana; entries
  idênticos colapsam numa linha com contador ("3"). ▶ re-dispara (Q12/Q13).
- ✅ **Tags** = só nome + active (confirma modelo). **Clients** = Name·Address·Currency
  (EUR) — SEM rate. **Projects** = Name·Client·Color·"Billable by default"·**Hourly
  rate**·estimate.
- ⚠️⚠️ **DIVERGÊNCIA CLAUDE.md vs Clockify — A RATE:** no Clockify a **rate é do
  PROJETO** (Project billable rate / Hourly rate), e o Client só tem currency. A
  CLAUDE.md decidiu o OPOSTO: "rate FIXA por cliente" (rate no Client). É escolha
  consciente nossa, mas o Clockify faz diferente. **ABRIR Q22 pra reconfirmar:
  rate no Client (CLAUDE.md) vs rate no Project (Clockify)?**
- ⚠️ **"Billable by default" vive no PROJETO** (toggle Yes/No) → reforça Q18(a): o
  default do flag billable vem do projeto. Sub-ponto da Q22 (onde mora a rate, mora
  o billable-default).
- Sidebar Clockify completa: Calendar·Dashboard·Reports·Projects·Team·Clients·Tags·
  Timesheet·Kiosks. **Team/Kiosks = fora** (single-user). **Timesheet** (grade semanal
  de entrada) = ÚNICO "talvez" — decidir se entra no escopo. Bate com a sidebar da
  CLAUDE.md (sem Team).
- Cortes confirmados nas telas: Project.Progress/Access/Forecast/Estimate/custom-fields;
  Client.Address; entry assignees; "Create invoice"; Status filter (provavelmente).

## Frentes (🏁 TODAS FECHADAS — 02/07/2026)
- ✅ ~~Extensão de Chrome~~ — FECHADA 100% (Q9/Q12/Q13/Q14/Q15/Q17).
- ✅ ~~Currency/rate histórica~~ — FECHADA (Q10/Q11/Q22).
- ✅ ~~Privacidade/encryption~~ — FECHADA (Q25).
- ✅ ~~Export/portabilidade~~ — FECHADA (Q26).
- ✅ ~~Edge cases editar-entry-rodando + fuso~~ — FECHADOS (Q23a/Q23b).
- ✅ ~~Relatório/export~~ — FECHADO (Q18–Q21, Q43, Q53–Q58): período (Q53), filtros
  (Q54), Weekly cortada (Q55), rounding (Q56), rodando fora (Q57), PORO `Report` (Q58).
- ✅ ~~Auth/convite/admin/landing~~ — FECHADO (Q28–Q38). Falta só a IMPLEMENTAÇÃO:
  login vira `find_by` (bug do `find_or_create_by`), coluna `User.suspended_at` +
  `User.admin` + `User.time_zone`, gate de suspensão no `require_authentication`
  (export isento), `AccessRequest` (email/name?/note?/status), landing na raiz
  (Q67), bootstrap `ADMIN_EMAIL`, painel de admin (Q68), e-mails de convite.
- ✅ ~~Telas Hotwire/PWA~~ — FECHADO (Q60–Q71): escopo de telas (Q59/Q60), URLs/home
  (Q61), CSS (Q62), estética moderna (Q63), dark automático (Q64), nav mobile
  (Q65/Q65b), Preferências (Q66), landing (Q67), admin (Q68), PWA/SW (Q69),
  tipografia (Q70), gráficos SVG (Q71).
- ✅ ~~Importador~~ — FECHADO (Q72): JSON único versionado, import só em bolha vazia.
- ✅ ~~Timesheet~~ — CORTADO DE VEZ (Q59): duração-pura conflita com a Q5.
- ✅ ~~Ramo CLI~~ — FECHADO (Q73–Q76): superfície JSON total (Q73), ponto-cli Go
  fork do fizzy-cli MIT (Q74), incremental pós-Timer (Q75), config herdada com
  adaptações self-hosted (Q76).
- 💤 **Cobrança $1/mês** — ADIADA por decisão do Alex (esboço Stripe registrado acima).
  ÚNICO tema não-grillado; retomar "quando houver gente pedindo acesso".

---

## Refinamentos de design pós-grilling (`/impeccable`, 03/07/2026)

> NÃO são grilling (entrevista pré-build) — são refinamentos das telas JÁ construídas,
> conduzidos com o skill `/impeccable` (init → critique → craft/layout/typeset/
> overdrive) e implementados via Codex sob orquestração. Registrados aqui pra o
> histórico de decisão ficar num lugar só. Racional completo no git (commits
> `441e356`..`273e37d`) e em `PRODUCT.md`/`DESIGN.md`.

### Tracker (`/home`) — critique 24→30/40 em 2 rodadas
- **Mobile:** barra do timer STICKY no topo (Stop nunca some ao rolar/abrir form
  manual); alvos de toque ≥44px (WCAG 2.5.5) no `.btn`/`.btn--sm`/tab bar.
- **Rótulo de dia:** "Hoje"/"Ontem" relativos ao FUSO DO USER (Q6) + dia da semana
  pt-BR nas datas antigas. Sem `I18n.l` (o app não carrega rails-i18n → levantaria).
- **Command palette ⌘K:** feature nova (não estava no grilling). `<dialog>` nativo
  inline no shell, busca substring, ações Timer/Navegação/Recentes, start/stop pelas
  rotas do timer (respeita o 409 da Q3/Q4/Q14). Gatilho de busca só no mobile.
- **Paginação (gem Pagy):** o tracker carregava TODAS as entries; agora pagina no SQL
  (50/página) e reagrupa em dias no fuso do user. "Carregar mais" funde o cabeçalho de
  dia na borda de página; total do dia recalculado SERVER-SIDE (não via param — era
  forjável). Fecha a lacuna de performance implícita da Q6.
- **Valor faturado na linha:** o `billable_amount` (Q18) agora aparece à direita da
  duração (tabular-nums, "—" quando não-faturável). Coluna direita em trilhas fixas
  pra colunar entre linhas ("o número parece certo", DESIGN.md).
- **a11y da palette:** navegação por setas com `aria-activedescendant`/`role=option`;
  Esc no `<details>` do split fecha só o interno.

### Landing (`/`) — overdrive
- O mockup do herói ganha VIDA: cronômetro ticando (rAF), count-up dos valores,
  donut/barras scroll-driven (`animation-timeline: view()`), marcador "agora" na régua.
- **⚠️ Decisão do dono que CONTRARIA a regra de reduced-motion:** os efeitos rodam
  MESMO sob `prefers-reduced-motion: reduce` (guards removidos + override do reset
  global do `base.css`, escopado à landing). É a ÚNICA exceção à acessibilidade de
  movimento no app; o resto honra a preferência. Reverter é um diff pequeno.
- **Copy (pt-BR + en em sincronia):** hero "Marque o ponto" → "Cronometre o trabalho"
  / "Track your time" (a ação real é cronometrar, não bater ponto); frozen "O número
  de janeiro..." → "Histórico sempre mantido"; removido "sem Node"; preço promocional
  US$1/mês vira asterisco + nota de rodapé ("se mudar, você é avisado antes").

### Tipografia (typeset)
- `font-optical-sizing: auto` + `font-kerning: normal` no `body` (InterVariable tem
  eixo opsz). Corpo mantido em 14px (densidade Linear é decisão de produto, não descuido).

## Adendo pós-grilling 2 — sessão 04/07/2026 (orquestração Fable → Codex → Opus)

> Refinamentos e DUAS reaberturas de decisão, pedidos ao vivo pelo dono. Implementação
> via Codex sob spec do orquestrador; validação adversarial por Opus (APROVADO).

### Q64 REABERTA: toggle de tema claro/escuro
- O dono pediu toggle manual. Decisão nova: **default segue o sistema, mas o usuário
  pode forçar** claro/escuro. `users.theme` (string `system|light|dark`, null: false,
  default "system"), select "Tema" na seção perfil de Preferências.
- Implementação: tokens migraram para **`light-dark()`** (uma declaração por token,
  fim do bloco `@media prefers-color-scheme`); `:root { color-scheme: light dark }` +
  override **`body[data-theme=...]`** — no `<body>` de propósito: o Turbo Drive troca
  o body na navegação mas NÃO atualiza atributos do `<html>`, então o tema novo
  aplica imediatamente após salvar Preferências (zero FOUC, zero JS novo).
- Landing/auth (layout `application`) NÃO emitem `data-theme` — seguem sempre o
  sistema (página pública). Tema forjado no PATCH → 422 (padrão da suíte).

### reduced-motion: REMOVIDO DO APP INTEIRO (amplia a exceção da landing)
- Decisão do dono: **o app ignora `prefers-reduced-motion` completamente** — caiu o
  reset global do base.css, o guard da palette e o override (agora redundante) da
  landing. Contra WCAG 2.3.3, consciente, documentado em comentário no base.css.

### Navegação suave (o "pisca e pula" entre telas)
- **View Transitions do Turbo 8**: `<meta name="view-transition" content="same-origin">`
  no head comum + cross-fade 0.15s (`::view-transition-old/new(root)`). Vale pra
  landing/admin também (head compartilhado — intencional).
- **Barra do timer `data-turbo-permanent`**: o frame lazy re-fetchava a cada navegação
  ("Carregando timer…" piscando). Permanente, o nó atravessa as navegações e o
  cronômetro segue ticando. Turbo Streams continuam alcançando o frame por id (a
  permanência só age no render de navegação). Trade-off aceito: hidden `page` pode
  ficar defasado (pior caso o redirect pós-stop volta pra página 1).

### Projeto padrão (feature nova)
- `users.default_project_id` — FK `on_delete: :nullify` (hard-delete de projeto limpa
  a referência), posse validada no model (projeto alheio → 422; isolamento Q23).
- UI: ação ⭐ "Definir/Remover padrão" no menu ⋮ de Projetos via sub-resource REST
  (`resource :default` aninhado, `Projects::DefaultsController`, escopo Action
  Policy — projeto alheio 404) + badge "Padrão" na linha. JSON de projects ganha
  campo escalar `default` (Q73/Q11).
- Pré-seleção no tracker: forms do timer e do entry manual usam
  `User#active_default_project` (nil se arquivado) como fallback **só em form novo**;
  re-render com erro respeita o que o usuário escolheu.

### Shell: dois fixes de CSS (bugs visuais reportados pelo dono)
- **Sidebar até o rodapé**: o wrapper do command palette é filho in-flow do
  `body.app` (grid) e criava uma segunda row implícita que roubava metade da sobra
  do `100dvh`. Fix: `grid-template-rows: 1fr`.
- **Menu ⋮ leve e uniforme**: itens sem borda/bloco (hover = tint sutil, destrutivo =
  texto vermelho, não laje sólida) e `width: 100%` — o summary do split (Dividir)
  não esticava por não ser filho direto do flex.
