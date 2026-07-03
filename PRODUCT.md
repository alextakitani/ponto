# Product

## Register

product

## Users

Uma pessoa técnica que roda o próprio homelab e quer controlar horas faturáveis
sem depender de um SaaS. Provavelmente freelancer, consultor ou dev que fatura
clientes por hora e precisa de um número confiável no fim do mês. Usa em duas
posturas: **no desktop** ao longo do dia de trabalho (liga/desliga o timer, edita
lançamentos, revisa relatórios) e **no celular via PWA** para start/stop rápido
longe da mesa. Cada conta é uma bolha isolada — o app é multi-usuário mas **sem
times, sem colaboração, sem dados compartilhados**. O único papel elevado é um
admin operacional que gerencia convites, nunca vê dados alheios.

A tarefa central em qualquer tela: **saber o que está rodando agora e chegar ao
start/stop sem procurar.** A barra do timer no topo é a assinatura — sempre
acessível. O entregável que justifica o produto é o **export CSV/Excel mensal**
com o qual o usuário fatura seus próprios clientes por fora.

## Product Purpose

Ponto é um time-tracker self-hosted enxuto, no espírito Clockify/Toggl mas sem o
peso — feito pra rodar num homelab e ser publicado como código aberto (licença
O'Saasy, proibido revender como SaaS). Rastreia horas na hierarquia
**Client → Project → Task → TimeEntry**, com rate faturável que herda do cliente
e congela por lançamento (snapshot), tags por fora, e relatórios Summary/Detailed
que desembocam no export.

Sucesso = a pessoa consegue, sem atrito, marcar horas o dia inteiro e no fim do
mês extrair um CSV/Excel correto por cliente/projeto. Backup é um arquivo SQLite.
O que o produto **deliberadamente não faz**: invoicing dos clientes do usuário
(ele fatura por fora), equipe/colaboração, OAuth/senha, custom fields,
estimativas/budget, timesheet em grade, calendar e dashboard. Enxuto é a feature.

## Brand Personality

**Preciso, quieto, denso.** A personalidade não vem do chrome — vem da confiança
de um número que está certo e de uma interface que não atrapalha. Voz direta, sem
firulas de marketing; a UI fala português, o código fala inglês. A cor é
funcional (cada projeto tem a sua; o app tem UM acento índigo). A única
assinatura visual permitida é a **barra do timer** no topo de toda tela — o resto
é hierarquia por tipografia, peso e espaço, no espírito Linear.

Três palavras: **preciso · enxuto · sem-atrito.**

## Anti-references

- **SaaS genérico com cards.** Nada de grades de cards idênticos (ícone + título +
  texto repetidos), hero-metric template (número gigante + label + stats + gradiente),
  ou dashboards inchados. O Ponto é linhas densas sem cards, hierarquia por tipografia.
- **Clockify/Toggl "cheios".** As dimensões de equipe (Team / Shared / Access),
  calendar e dashboard duplicado foram cortados no design. Onde o Clockify mostra
  colaboração, ignorar. É o núcleo do Clockify, não o Clockify inteiro.
- **Retrô anos-90.** A estética original do brief foi revogada (Q63). Nada de
  skeumorfismo, serrilhado, ou nostalgia-terminal decorativa.
- **Enterprise pesado.** Chrome ruidoso, bordas e sombras por toda parte, cor
  espalhada. O Ponto usa UM acento, chrome quieto, base neutra quase-branca /
  quase-preta. Densidade vem do espaço, não de linhas.

## Design Principles

1. **A barra do timer é sagrada.** Start/stop sempre visível e a um clique, em
   toda tela, desktop e mobile. É a assinatura e o caminho crítico — nada compete
   com ela por atenção.
2. **Densidade por espaço, não por chrome.** Muita informação por tela usando
   tipografia, peso e ritmo de espaço — não cards, bordas ou sombras. Uma linha é
   uma linha.
3. **Um acento, cor com trabalho a fazer.** O índigo marca só o estado ativo e a
   ação primária. A cor "livre" pertence aos projetos (a bolinha/gráfico), que dão
   a personalidade. Cor sem função é ruído.
4. **O número está certo — e parece certo.** `tabular-nums` em toda coluna
   numérica, snapshot de rate que não revaloriza histórico, corte de dia no fuso
   do usuário. A precisão do domínio se reflete no cuidado visual.
5. **Zero-build, zero-JS onde der.** Custom properties sem Tailwind, gráficos SVG
   server-rendered, Hotwire em vez de JS avulso. A restrição técnica (importmap,
   sem Node no runtime) é também uma disciplina estética: nada supérfluo.

## Accessibility & Inclusion

Alvo **WCAG AA**, já sustentado pelos tokens e mantido em código novo:

- **Contraste AA** garantido nos dois temas — corpo ≥ 4.5:1, texto grande ≥ 3:1.
  Texto secundário (`--color-text-subtle`) fica em ~5.4–5.6:1; não descer disso
  "por elegância". Placeholder segue o mesmo piso do corpo.
- **Dark automático** via `prefers-color-scheme`, sem toggle (Q64) — mesmos tokens
  semânticos com valores nos dois temas.
- **Foco visível só-teclado** (`:focus-visible` com anel de acento); mouse não
  mostra outline.
- **`prefers-reduced-motion: reduce`** honrado globalmente (animações/transições
  ~instantâneas). Toda animação nova precisa de alternativa reduzida.
- **Ícone sempre acompanha label** (Q63) — nunca ação só-ícone sem texto; ícones
  herdam `currentColor`.
- **Daltonismo:** cor nunca é o único sinal. Estado ativo do timer usa cor **e**
  peso/posição; a bolinha do projeto acompanha sempre o nome.
