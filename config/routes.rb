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
