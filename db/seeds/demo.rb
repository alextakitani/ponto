# Seed de DEMO isolado (email demo@ponto.app) — dados 100% fictícios pra screenshots
# da landing / testes manuais. NÃO toca em nenhuma outra conta (tudo escopado por
# user_id). Idempotente: recria a bolha do zero a cada run.
# Rodar: bin/rails runner db/seeds/demo.rb
require "active_support/all"

DEMO_EMAIL = "demo@ponto.app"
tz = "America/Sao_Paulo"
zone = ActiveSupport::TimeZone[tz]

user = User.find_or_initialize_by(email: DEMO_EMAIL)
user.assign_attributes(time_zone: tz, onboarded_at: Time.current, locale: "pt-BR")
user.admin = false if user.respond_to?(:admin=)
user.save!

# Limpa a bolha de demo (idempotência) — só desta conta.
user.time_entries.delete_all
Tagging.where(time_entry_id: TimeEntry.unscoped.where(user_id: user.id).select(:id)).delete_all rescue nil
user.tags.destroy_all
user.projects.destroy_all
user.clients.destroy_all

# --- Clientes (moeda + rate padrão) --------------------------------------------
acme   = user.clients.create!(name: "Aurora Studio",  currency: "BRL", rate_cents: 18000)
northwind = user.clients.create!(name: "Northwind Labs", currency: "USD", rate_cents: 9500)
solo   = user.clients.create!(name: "Café Quântico", currency: "BRL", rate_cents: 14000)

# --- Projetos (cor própria; rate herda do cliente salvo override) --------------
p_site   = user.projects.create!(name: "Site institucional", client: acme,    color: "#7c3aed")
p_app    = user.projects.create!(name: "App de pedidos",     client: acme,    color: "#0ea5e9", rate_cents: 20000)
p_api    = user.projects.create!(name: "Plataforma de API",  client: northwind, color: "#f97316")
p_infra  = user.projects.create!(name: "Homelab & infra",    client: solo,    color: "#22c55e")
p_marca  = user.projects.create!(name: "Identidade visual",  client: solo,    color: "#ec4899")
projects = [ p_site, p_app, p_api, p_infra, p_marca ]

# --- Tarefas -------------------------------------------------------------------
tasks = {
  p_site  => [ "Layout", "Conteúdo", "Deploy" ],
  p_app   => [ "Checkout", "Push", "Testes" ],
  p_api   => [ "Auth", "Webhooks", "Docs" ],
  p_infra => [ "Kubernetes", "Backups" ],
  p_marca => [ "Logo", "Guia de marca" ]
}.transform_values { |names| names.map { |n| nil } } # placeholder, preenchido abaixo
tasks = {}
{
  p_site  => %w[Layout Conteúdo Deploy],
  p_app   => %w[Checkout Push Testes],
  p_api   => %w[Auth Webhooks Docs],
  p_infra => %w[Kubernetes Backups],
  p_marca => %w[Logo Guia]
}.each do |project, names|
  tasks[project] = names.map { |n| project.tasks.create!(name: n, user: user) }
end

# --- Tags ----------------------------------------------------------------------
tag_names = %w[foco reunião bug urgente pesquisa]
tags = tag_names.map { |n| user.tags.create!(name: n) }

# --- Lançamentos: ~5 semanas, dias úteis, 2–4 blocos/dia -----------------------
descriptions = {
  p_site  => [ "ajustes no layout da home", "revisão de conteúdo", "deploy de staging", "acessibilidade do menu" ],
  p_app   => [ "fluxo de checkout", "notificações push", "cobertura de testes", "correção de carrinho" ],
  p_api   => [ "endpoint de autenticação", "assinatura de webhooks", "docs da API pública", "rate limiting" ],
  p_infra => [ "upgrade do cluster", "rotina de backup", "monitoramento de nós", "migração de ingress" ],
  p_marca => [ "explorações de logo", "paleta e tipografia", "guia de marca v1" ]
}

today = Time.current.in_time_zone(zone).to_date
rng = Random.new(42) # determinístico → mesmas telas em recapturas

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

puts "Demo pronta: #{user.email}"
puts "  clientes=#{user.clients.count} projetos=#{user.projects.count} " \
     "tarefas=#{Task.unscoped.where(user_id: user.id).count} tags=#{user.tags.count} " \
     "lançamentos=#{user.time_entries.count} (#{created} criados)"
