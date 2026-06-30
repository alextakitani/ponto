# Grilling — Ponto (time-tracker) — progresso

> Sessão de grilling (/grilling) sobre as frentes em aberto do design.
> Última sessão: 30/06/2026. **▶ RETOMAR NA QUESTÃO 27** (Q1–Q26 fechadas).
> Revisões importantes: Q3/Q4 revisadas pela Q14; Q1 parcialmente revogada pela Q15;
> Q11 estendida pela Q18; **Q23 revoga o "single-user/User-único" → app MULTI-USUÁRIO**;
> Q24 = acesso por CONVITE + admin + landing; Q25 = privacidade/encryption;
> Q26 = export/portabilidade.
> 💤 **Cobrança $1/mês = ADIADA explicitamente** (Alex: "não quero grilar agora,
> cobrança vou fazer depois"). Esboço registrado abaixo, NÃO grillado.
> ✅ **CLAUDE.md reconciliada em 30/06** com Q1–Q24 (multi-user, rate override,
> project_id nulável, billable, convite/admin, fuso por user, money-rails, export).
> **Ramo da extensão de Chrome: FECHADO 100%** (Q9, Q12, Q13, Q14, Q15, Q17).
> **Ramo Relatório/Export: EM ANDAMENTO** (Q18+; ref: xlsx real do Clockify em
> `~/Dropbox/empresa/Kube/invoices/2026/Clockify_Time_Report_Detailed_05_01_2026-05_31_2026.xlsx`).

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

## Frentes ainda não grilladas (próximos ramos da árvore) — escolher na Q27
- ✅ ~~Extensão de Chrome~~ — FECHADA 100% (Q9/Q12/Q13/Q14/Q15/Q17).
- ✅ ~~Currency/rate histórica~~ — FECHADA (Q10/Q11/Q22).
- ✅ ~~Privacidade/encryption~~ — FECHADA (Q25).
- ✅ ~~Export/portabilidade~~ — FECHADA (Q26) [falta detalhar o IMPORTADOR].
- ✅ ~~Edge cases editar-entry-rodando + fuso~~ — FECHADOS (Q23a/Q23b).
- **Relatório/export** (entregável principal — PARCIAL, Q18–Q21 feitas): falta toggle
  **Rounding** de tempo (bloco/direção/granularidade, adiado da Q11), **seletor de
  período** (This month + setas ‹›), **filtros finos** (Client/Project/Task/Tag/
  Description; Status?), view **Weekly**, e o **contrato exato das consultas** de
  agrupamento (uma/duas dimensões aninhadas — Q21).
- **Auth/convite/admin/landing** (RAMO NOVO, aberto pela Q24 — FRESCO): fluxo de
  convite (admin cria user → e-mail → 1º login), tela de admin (lista users + fila
  AccessRequest + aprovar/recusar), a landing (copy/form), e-mail de convite vs
  magic-code, bootstrap do 1º-user-admin.
- **Telas Hotwire/PWA**: Clients → Projects → Tasks → Timer → Tags → Relatórios →
  Export; timer global no topo; sidebar; start/stop via Turbo/Stimulus; **edição
  INLINE por linha** (Turbo Frame — descoberta do tour); Split/Duplicate (extras?).
- **Importador** (par do export Q26) — contrato de importação entre instâncias.
- **Timesheet** (grade semanal de entrada) — o ÚNICO "talvez" do tour; decidir se entra.
- 💤 **Cobrança $1/mês** — ADIADA por decisão do Alex (esboço Stripe registrado acima).
