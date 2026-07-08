Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA (decisões §2): manifest + service worker servidos por app/views/pwa/*.
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Auth passwordless de duas etapas (decisões §3).
  get    "sign_in"         => "sessions#new",            as: :sign_in
  post   "sign_in"         => "sessions#create"
  get    "sign_in/verify"  => "sessions#verify",         as: :verify_sign_in
  post   "sign_in/session" => "sessions#create_session", as: :sign_in_session
  delete "sign_out"        => "sessions#destroy",        as: :sign_out

  # Página "conta suspensa" (Q34): acessível pelo user suspenso (isenta do gate),
  # senão o redirect entraria em loop.
  get "suspended" => "suspensions#show", as: :suspended

  # Landing pública na raiz (Q36/Q67): anônimo vê a landing; logado é
  # redirecionado pra home. Pedido de acesso público grava um AccessRequest (Q24).
  root "landing#show"
  resources :access_requests, only: :create

  # Home protegida (placeholder até as telas de domínio). É pra onde o login
  # cai: after_authentication_url volta pra root_url, e a landing redireciona
  # o logado pra cá.
  get "home" => "home#show", as: :home

  resource :welcome, only: :show, controller: :welcome
  resource :onboarding_skip, only: :create
  resources :clockify_imports, only: %i[new create show]

  resource :preferences, only: %i[show update] do
    resources :access_tokens, only: %i[create destroy], shallow: true
  end

  # Relatórios (Fatia 5.1) — o entregável principal. PÁGINA ÚNICA com abas
  # Summary/Detailed via param `view`; período/filtros/group_by/rounding viajam na
  # URL (pra 5.2 herdar no export e pro compartilhamento de link). Só :index (é uma
  # consulta sem estado no servidor — o PORO Report monta tudo dos params).
  resources :reports, only: :index do
    # Export .xlsx/.csv (Fatia 5.2) — o entregável principal. Mesmo recorte da tela
    # (período/filtros viajam na URL); o formato vem da extensão (.xlsx/.csv).
    get :export, on: :collection
  end

  # Clientes (Fatia 2.2) — 1ª tabela de domínio. Arquivar/desarquivar seguem a
  # disciplina REST do projeto (STYLE.md): ação sem verbo padrão vira sub-resource
  # singular, não custom action. Espelha o `resource :suspension` do admin:
  #   arquivar    = POST   /clients/:id/archival   (cria o arquivamento)
  #   desarquivar = DELETE /clients/:id/archival   (remove o arquivamento)
  resources :clients do
    resource :archival, only: %i[create destroy], module: :clients
  end

  resources :tags do
    resource :archival, only: %i[create destroy], module: :tags
  end

  # Projetos (Fatia 2.3) — irmão do Client. Mesmo padrão REST: arquivar/desarquivar
  # via sub-resource singular `archival` (não custom action — STYLE.md). Tasks
  # (sub-bucket do projeto — Q1) vivem ANINHADAS sob o projeto, com shallow: as ações
  # de membro (show/edit/update/destroy) ganham rota rasa `/tasks/:id` (não precisam
  # do project_id), mas index/create/new ficam sob `/projects/:project_id/tasks`
  # (precisam saber a QUAL projeto pertencem). Archival da task idem (aninhado no id raso).
  resources :projects do
    resource :archival, only: %i[create destroy], module: :projects
    resource :default, only: %i[create destroy], module: :projects

    resources :tasks, shallow: true, module: :projects do
      resource :archival, only: %i[create destroy], module: :tasks
    end
  end

  # Tracker (Fatia 3.1): o timer atual é um resource SINGULAR (Q13/Q14); as
  # entradas de tempo são CRUD normal, sempre escopadas ao Current.user.
  resource :timer, only: %i[show create destroy]
  resources :tracker_entries, only: :index
  # Split (Q48): dividir um entry em dois é ação SEM verbo padrão → sub-resource
  # singular aninhado (STYLE.md), não custom action: POST /time_entries/:id/split.
  resources :time_entries, only: %i[index show edit create update destroy] do
    resource :split, only: :create, module: :time_entries
    # Duplicate (Q47/Q13): re-disparar copiando os campos pra um timer novo. Também
    # é ação sem verbo padrão → sub-resource singular: POST /time_entries/:id/duplicate.
    resource :duplicate, only: :create, module: :time_entries
  end

  # Painel de admin (Q68) — PÁGINA ÚNICA em /admin (dashboard#show) com dois
  # resources REST por baixo. Regra do projeto (STYLE.md): ação sem verbo padrão
  # vira resource/membro REST, não custom action. Por isso suspensão/reativação/
  # promoção/rebaixamento viram SUB-RESOURCES singulares aninhados em user (cada
  # um com seu par create/destroy REST), em vez de POSTs custom soltos:
  #   suspender  = POST   /admin/users/:id/suspension   (cria a suspensão)
  #   reativar   = DELETE /admin/users/:id/suspension   (remove a suspensão)
  #   promover   = POST   /admin/users/:id/admin_role    (concede admin)
  #   rebaixar   = DELETE /admin/users/:id/admin_role    (revoga admin)
  #   reenviar   = POST   /admin/users/:id/invitation    (re-dispara o convite)
  # users: só create (convidar) e destroy (deletar). access_requests: aprovar/
  # recusar viram sub-resources singulares (approval/rejection) — mesma disciplina.
  namespace :admin do
    root "dashboard#show"

    # Analytics via AhoyCaptain. A autorização (só admin) é injetada no
    # ApplicationController da engine em config/initializers/ahoy_captain.rb —
    # NÃO num constraint de rota (req.cookie_jar não tem key generator ali:
    # "undefined method 'generate_key' for nil"). O gate real reusa a
    # Authentication do app.
    mount AhoyCaptain::Engine => "/analytics", as: :analytics

    # Uso da API (CLI/extensão via Bearer). O AhoyCaptain só mostra visitas de
    # browser ($view) e ancora TODAS as telas num JOIN com ahoy_visits; os
    # acessos de máquina são gravados como eventos `api_request` SEM visita (ver
    # ApplicationController#track_api_request), então o join os elimina e eles
    # nunca aparecem no dashboard da engine. Esta página os lê direto.
    resource :api_usage, only: :show, controller: :api_usage

    resources :users, only: %i[create destroy] do
      resource :suspension,  only: %i[create destroy], module: :users
      resource :admin_role,  only: %i[create destroy], module: :users
      resource :invitation,  only: :create,            module: :users
    end

    resources :access_requests, only: [] do
      resource :approval,  only: :create, module: :access_requests
      resource :rejection, only: :create, module: :access_requests
    end
  end
end
