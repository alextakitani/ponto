# Decisões de auth/config — o que clonamos do Fizzy

> Complemento de `time-tracker-decisoes.md`. Registra **o que foi adotado do
> `basecamp/fizzy`** (a referência de implementação, §1 do doc principal), o que
> foi **adaptado** e o que ficou **fora de escopo**. Atualizado em 29/06/2026.
>
> Lembrete de licença (§1 do doc principal): o Fizzy usa "O'Saasy License". Aqui
> clonamos **padrões**, reescrevendo no nosso projeto — não copiamos trechos
> tratando como open-source padrão.

---

## 1. Adotado (auth)

### Session por `signed_id` (sem coluna `token`)
A sessão é identificada no cookie pelo `signed_id` do Rails, não por uma coluna
`token` própria. O concern usa `Session.find_signed(cookie)` e grava
`session.signed_id` no cookie assinado, `httponly`, `same_site: :lax`.
- Arquivo: `app/controllers/concerns/authentication.rb`.

### `pending_authentication_token` assinado entre as duas etapas
O e-mail "pendente de autenticação" viaja num **cookie assinado**
(`Rails.application.message_verifier(:pending_authentication)`), **não na URL**.
À prova de adulteração, expira junto com o código. Na etapa 2 confirmamos com
`ActiveSupport::SecurityUtils.secure_compare`.
- Por quê: o esboço anterior passava `?email=` em claro, adulterável.
- Arquivos: `app/controllers/concerns/authentication/via_sign_in_code.rb`,
  `app/controllers/sessions_controller.rb`.

### Código servido em dev via flash + header, com guarda anti-vazamento
Clone de `Authentication::ViaMagicLink`. Em desenvolvimento o código de 6 dígitos
vai pra `flash[:sign_in_code]` **e** pro header `X-Sign-In-Code` (facilita teste
e automação). Um `after_action` (`ensure_development_code_not_leaked`) dá `raise`
se o flash do código existir fora de `development` — barreira contra vazamento.
- Arquivo: `via_sign_in_code.rb`.

### `AccessToken` com escopo `read`/`write`
`enum permission: read|write`. `allows?(method)` → `GET`/`HEAD` sempre livres;
métodos de escrita exigem `write?`. `User.find_by_permissable_access_token(token,
method:)` resolve o usuário e já registra `last_used_at`.
- Por quê: cobre "escopado por método HTTP" (§3 do doc principal) de forma mais
  simples que a CSV `"GET,POST"` do esboço, e é o padrão exato do Fizzy.
- Arquivos: `app/models/access_token.rb`, `app/models/user.rb`.

### `Current` com setter em cascata
`Current.session=` resolve `Current.user` automaticamente; `Current` também
carrega `request_id`, `user_agent`, `ip_address` (setados num `before_action`).
- Arquivos: `app/models/current.rb`, `authentication.rb`.

---

## 2. Adaptado (diferença consciente vs. Fizzy)

### Código: **6 dígitos + digest**, não base32 em claro
O Fizzy guarda o código `base32` em claro com `find_by(code:)`. Mantivemos
**dígitos** (decisões §3 é explícito: "código de 6 dígitos") e guardamos só o
**digest SHA256** — mais seguro. `SignInCode::Code.sanitize` tolera o que o
humano digita (espaços, traços), variante "só dígitos" do `MagicLink::Code`.
- Arquivos: `app/models/sign_in_code.rb`, `app/models/sign_in_code/code.rb`.

### CSRF: `verified_request?` custom, **não** `using: :header_only`
O Fizzy roda Rails **edge** e usa `protect_from_forgery using: :header_only`.
**Essa estratégia não existe no Rails 8.1.3** (é só no `main`). Obtivemos o mesmo
efeito sobrescrevendo `verified_request?` para tratar como verificado o request
que é claramente da extensão: **JSON + `Authorization: Bearer`**. Esse já é
autenticado pelo `AccessToken` (escopado por método) e nenhuma navegação de
browser carrega Bearer — então dispensar CSRF aí é seguro.
- Por quê isso importa: sem essa isenção, `DELETE/POST` JSON da extensão tomavam
  **422 (InvalidAuthenticityToken)** antes de chegar ao escopo do token.
- Arquivo: `app/controllers/concerns/request_forgery_protection.rb`.
- ⚠️ Se um dia subir pra Rails edge, dá pra trocar pelo `header_only` nativo.

---

## 3. Fora de escopo (cortado pelo doc principal §3/§6)

Não trazidos do Fizzy, por decisão de produto:
- **Multi-tenancy**: `Identity → Users → Accounts`, `require_account`,
  `disallow_account_scope`, `Authorization`. Colapsado num `User` único (§3).
- **Passkeys / WebAuthn** (§3: "fora por ora").
- **Signup / `Account.accepting_signups?` / transfers de sessão** — `User` único,
  sem auto-cadastro multiusuário (§6).
- **Web push / VAPID, mission_control, stack de teste VCR/webmock/mocha** — sem
  chamadas HTTP externas que justifiquem.

---

## 4. Backlog — padrões do Fizzy a trazer nas próximas fases

Mapeiam direto pras frentes abertas (§10 do doc principal):

- **`CurrentTimezone` (`around_action Time.use_zone`)** → relatórios/§8. O corte
  do dia é `.in_time_zone("America/Sao_Paulo").to_date` feito no Ruby. Exemplo
  vivo no Fizzy: `app/models/user/day_timeline.rb`.
- **`TurboFlash`** (`turbo_stream.replace(:flash, ...)`) → telas Hotwire.
- **Stimulus controllers reusáveis** do Fizzy (1-a-1, conforme a tela precisar):
  `auto_submit`, `auto_save`, `autoresize`, `copy_to_clipboard` (útil pro token
  da extensão), `dialog`, `combobox`.
- **PWA** (`pwa/manifest.json.erb` + `service_worker.js.erb`) → §2. As rotas já
  estão habilitadas em `config/routes.rb`; faltam as views.

### Avaliado e provavelmente descartado
- **Shims SQLite-como-MySQL** (`table_definition_column_limits`,
  `sqlite_schema_dumper` p/ FTS5): YAGNI. O doc escolheu SQLite *porque*
  backup = 1 arquivo, sem intenção de MySQL. Revisitar só se a busca de entries
  exigir full-text.
