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

  # Landing pública na raiz (Q36/Q67): anônimo vê a landing; logado é
  # redirecionado pra home. Pedido de acesso público grava um AccessRequest (Q24).
  root "landing#show"
  resources :access_requests, only: :create

  # Home protegida (placeholder até as telas de domínio). É pra onde o login
  # cai: after_authentication_url volta pra root_url, e a landing redireciona
  # o logado pra cá.
  get "home" => "home#show", as: :home
end
