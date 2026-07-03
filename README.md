# Ponto

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

## Ponto Cloud

Não quer hospedar? A instância gerenciada custa **US$ 1/mês** (preço promocional — se
um dia mudar, você é avisado antes). Acesso por convite: peça o seu na
[landing](https://github.com/alextakitani/ponto).

## Licença

**O'Saasy License** (ver [`LICENSE.md`](LICENSE.md)) — código aberto, mas **proibido
revender como SaaS**. Leia, audite, contribua, hospede onde quiser.
