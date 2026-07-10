# Ponto

**🇧🇷 Português** · [🇺🇸 English](#-english)

Time-tracker self-hosted, enxuto, para quem cobra por hora. Cronometre o trabalho,
organize em **Cliente → Projeto → Tarefa** com valor-hora por cliente (em real, euro,
qualquer moeda), e no fim do mês exporte um relatório **.xlsx/CSV pronto pra virar
fatura**. Roda no seu servidor — seus dados ficam com você.

No espírito do Clockify/Toggl, mas sem o peso: sem equipe, sem colaboração, sem
dashboards inchados. Multi-usuário (cada conta é uma bolha isolada), acesso por
convite.

## Stack

- **Ruby 4.0** · **Rails 8.1** · **Hotwire** (Turbo + Stimulus)
- **SQLite** — backup é copiar um arquivo
- **importmap** — sem build de JS, sem Node no runtime
- **PWA** responsiva (mesma UI no desktop e no mobile)
- Auth **passwordless** (magic code de 6 dígitos, sem senha/OAuth)
- Estética moderna minimal densa (estilo Linear); claro + dark automático

## Rodar em desenvolvimento

```bash
bin/setup            # instala gems, prepara o banco
bin/rails server     # http://localhost:3000
```

Primeiro acesso: com o banco vazio, só o e-mail definido em `ADMIN_EMAIL`
(ver `.env.example`) consegue criar conta — e essa conta vira o admin. Depois disso,
o acesso é por convite (o admin aprova pedidos vindos da landing).

## Testes e qualidade

```bash
bin/rails test                 # Minitest — deve passar 100%
bin/brakeman -q --no-pager     # segurança — 0 warnings
bin/rubocop                    # estilo (rubocop-rails-omakase)
```

## Self-host

O repositório já traz o **Dockerfile** e a configuração do **Kamal**
(`config/deploy.yml`). Em resumo:

1. `git clone` no seu servidor (ou na sua máquina, pra experimentar).
2. Deploy com Docker ou `kamal setup`.
3. Configure `ADMIN_EMAIL` e o SMTP (o login manda um código por e-mail).
4. O primeiro acesso com o `ADMIN_EMAIL` cria o administrador; a partir dele, convide
   quem quiser.

## Ecossistema

- **[ponto-cli](https://github.com/alextakitani/ponto-cli)** — CLI oficial (Go): timer,
  catálogo e export do terminal ou via agentes de IA. Usa o mesmo token da extensão.
- **[ponto-extension](https://github.com/Rafatakitani/ponto-extension)** — extensão de
  Chrome pro timer no navegador. Usa o mesmo token da CLI.

## Ponto Cloud

Não quer hospedar? A instância gerenciada custa **US$ 1/mês** (preço promocional — se
um dia mudar, você é avisado antes). Acesso por convite: peça o seu em
[pontotracker.com](https://pontotracker.com/).

## Licença

**O'Saasy License** (ver [`LICENSE.md`](LICENSE.md)) — código aberto, mas **proibido
revender como SaaS**. Leia, audite, contribua, hospede onde quiser.

---

## 🇺🇸 English

[🇧🇷 Português](#ponto) · **🇺🇸 English**

A lean, self-hosted time tracker for people who bill by the hour. Track your work,
organize it as **Client → Project → Task** with a per-client hourly rate (in dollars,
euros, any currency), and at month's end export an **.xlsx/CSV report ready to become
an invoice**. Runs on your own server — your data stays with you.

In the spirit of Clockify/Toggl, but without the weight: no teams, no collaboration,
no bloated dashboards. Multi-user (each account is an isolated bubble), invite-only
access.

### Stack

- **Ruby 4.0** · **Rails 8.1** · **Hotwire** (Turbo + Stimulus)
- **SQLite** — backup is copying one file
- **importmap** — no JS build, no Node at runtime
- **PWA** responsive (same UI on desktop and mobile)
- **Passwordless** auth (6-digit magic code, no password/OAuth)
- Modern minimal-dense aesthetic (Linear-style); automatic light + dark

### Development

```bash
bin/setup            # install gems, prepare the database
bin/rails server     # http://localhost:3000
```

First run: with an empty database, only the email set in `ADMIN_EMAIL`
(see `.env.example`) can create an account — and that account becomes the admin.
After that, access is invite-only (the admin approves requests from the landing page).

### Tests and quality

```bash
bin/rails test                 # Minitest — must pass 100%
bin/brakeman -q --no-pager     # security — 0 warnings
bin/rubocop                    # style (rubocop-rails-omakase)
```

### Self-host

The repo already ships the **Dockerfile** and **Kamal** config
(`config/deploy.yml`). In short:

1. `git clone` onto your server (or your own machine, to try it out).
2. Deploy with Docker or `kamal setup`.
3. Set `ADMIN_EMAIL` and SMTP (sign-in emails a code).
4. The first sign-in with `ADMIN_EMAIL` creates the admin; from there, invite whoever
   you want.

### Ecosystem

- **[ponto-cli](https://github.com/alextakitani/ponto-cli)** — official CLI (Go): timer,
  catalog and export from your terminal or through AI agents. Uses the same token as the
  extension.
- **[ponto-extension](https://github.com/Rafatakitani/ponto-extension)** — Chrome
  extension for the timer in your browser. Uses the same token as the CLI.

### Ponto Cloud

Don't want to self-host? The managed instance is **US$ 1/month** (a promotional price —
if it ever changes, you'll be told first). Invite-only: request yours at
[pontotracker.com](https://pontotracker.com/).

### License

**O'Saasy License** (see [`LICENSE.md`](LICENSE.md)) — open source, but **you may not
resell it as a SaaS**. Read it, audit it, contribute, host it wherever you like.
