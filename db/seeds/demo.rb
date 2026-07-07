# Seed de DEMO isolado (email demo@ponto.app) — dados 100% fictícios pra screenshots
# da landing / testes manuais. NÃO toca em nenhuma outra conta (tudo escopado por
# user_id). Idempotente: recria a bolha do zero a cada run.
#
# Bilíngue (a landing é bilíngue → precisa das telas nos dois idiomas):
#   bin/rails runner db/seeds/demo.rb            # pt-BR (default)
#   DEMO_LOCALE=en bin/rails runner db/seeds/demo.rb   # inglês
# O locale do User também é setado pra o idioma escolhido, então a UI sai no mesmo.
# Mesma seed de RNG nos dois → layout idêntico, só as strings mudam.
require "active_support/all"

DEMO_EMAIL = "demo@ponto.app"
locale = ENV["DEMO_LOCALE"].to_s.downcase == "en" ? "en" : "pt-BR"
tz = "America/Sao_Paulo"
zone = ActiveSupport::TimeZone[tz]

user = User.find_or_initialize_by(email: DEMO_EMAIL)
user.assign_attributes(time_zone: tz, onboarded_at: Time.current, locale: locale)
user.admin = false if user.respond_to?(:admin=)
user.save!

# Limpa a bolha de demo (idempotência) — só desta conta. Ordem importa por causa
# das FKs: solta o default_project, apaga taggings → entries → tags → projetos →
# clientes. destroy (não delete_all) pra os callbacks/joins caírem certo.
user.update_column(:default_project_id, nil) if user.respond_to?(:default_project_id)
entry_ids = TimeEntry.unscoped.where(user_id: user.id).pluck(:id)
Tagging.where(time_entry_id: entry_ids).delete_all if entry_ids.any?
user.time_entries.destroy_all
user.tags.destroy_all
user.projects.destroy_all
user.clients.destroy_all

en = locale == "en"

# --- Clientes (moeda + rate padrão) --------------------------------------------
acme      = user.clients.create!(name: en ? "Aurora Studio" : "Aurora Studio", currency: "BRL", rate_cents: 18000)
northwind = user.clients.create!(name: "Northwind Labs", currency: "USD", rate_cents: 9500)
solo      = user.clients.create!(name: en ? "Quantum Coffee" : "Café Quântico", currency: "BRL", rate_cents: 14000)

# --- Projetos (cor própria; rate herda do cliente salvo override) --------------
# Cores/ordem/currency IDÊNTICAS entre idiomas → mesmo layout no screenshot.
p_site  = user.projects.create!(name: en ? "Marketing site"    : "Site institucional", client: acme,      color: "#7c3aed")
p_app   = user.projects.create!(name: en ? "Ordering app"      : "App de pedidos",     client: acme,      color: "#0ea5e9", rate_cents: 20000)
p_api   = user.projects.create!(name: en ? "API platform"      : "Plataforma de API",  client: northwind, color: "#f97316")
p_infra = user.projects.create!(name: en ? "Homelab & infra"   : "Homelab & infra",    client: solo,      color: "#22c55e")
p_brand = user.projects.create!(name: en ? "Brand identity"    : "Identidade visual",  client: solo,      color: "#ec4899")
projects = [ p_site, p_app, p_api, p_infra, p_brand ]

# --- Tarefas -------------------------------------------------------------------
task_names = if en
  { p_site => %w[Layout Content Deploy], p_app => %w[Checkout Push Tests],
    p_api => %w[Auth Webhooks Docs], p_infra => %w[Kubernetes Backups],
    p_brand => %w[Logo Guidelines] }
else
  { p_site => %w[Layout Conteúdo Deploy], p_app => %w[Checkout Push Testes],
    p_api => %w[Auth Webhooks Docs], p_infra => %w[Kubernetes Backups],
    p_brand => %w[Logo Guia] }
end
tasks = {}
task_names.each do |project, names|
  tasks[project] = names.map { |n| project.tasks.create!(name: n, user: user) }
end

# --- Tags ----------------------------------------------------------------------
tag_names = en ? %w[focus meeting bug urgent research] : %w[foco reunião bug urgente pesquisa]
tags = tag_names.map { |n| user.tags.create!(name: n) }

# --- Descrições dos lançamentos ------------------------------------------------
descriptions = if en
  { p_site  => [ "home layout tweaks", "content review", "staging deploy", "menu accessibility" ],
    p_app   => [ "checkout flow", "push notifications", "test coverage", "cart fix" ],
    p_api   => [ "auth endpoint", "webhook signing", "public API docs", "rate limiting" ],
    p_infra => [ "cluster upgrade", "backup routine", "node monitoring", "ingress migration" ],
    p_brand => [ "logo explorations", "palette and type", "brand guide v1" ] }
else
  { p_site  => [ "ajustes no layout da home", "revisão de conteúdo", "deploy de staging", "acessibilidade do menu" ],
    p_app   => [ "fluxo de checkout", "notificações push", "cobertura de testes", "correção de carrinho" ],
    p_api   => [ "endpoint de autenticação", "assinatura de webhooks", "docs da API pública", "rate limiting" ],
    p_infra => [ "upgrade do cluster", "rotina de backup", "monitoramento de nós", "migração de ingress" ],
    p_brand => [ "explorações de logo", "paleta e tipografia", "guia de marca v1" ] }
end

# --- Lançamentos: ~5 semanas, dias úteis, 2–4 blocos/dia -----------------------
today = Time.current.in_time_zone(zone).to_date
rng = Random.new(42) # determinístico → mesmo layout em recapturas e entre idiomas

created = 0
(0..38).each do |days_ago|
  date = today - days_ago
  next if date.saturday? || date.sunday?

  blocks = rng.rand(2..4)
  cursor = zone.local(date.year, date.month, date.day, 9, rng.rand(0..30), 0)

  blocks.times do
    project = projects.sample(random: rng)
    task = tasks[project].sample(random: rng)
    desc = descriptions[project].sample(random: rng)
    minutes = [ 45, 60, 75, 90, 120, 150 ].sample(random: rng)

    started = cursor
    ended = started + minutes.minutes
    entry = user.time_entries.create!(
      project: project,
      task: task,
      description: desc,
      started_at: started.utc,
      ended_at: ended.utc,
      billable: rng.rand < 0.85
    )
    entry.tags << tags.sample(random: rng) if rng.rand < 0.5
    created += 1

    # próximo bloco começa depois de um intervalo curto
    cursor = ended + rng.rand(10..40).minutes
  end
end

# default project pra barra do timer
user.update!(default_project_id: p_app.id) if user.respond_to?(:default_project_id)

puts "Demo pronta (#{locale}): #{user.email}"
puts "  clientes=#{user.clients.count} projetos=#{user.projects.count} " \
     "tarefas=#{Task.unscoped.where(user_id: user.id).count} tags=#{user.tags.count} " \
     "lançamentos=#{user.time_entries.count} (#{created} criados)"
