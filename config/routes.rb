Rails.application.routes.draw do
  devise_for :users

  # Health check (load balancers / uptime).
  get "up" => "rails/health#show", as: :rails_health_check

  # Raiz: dashboard (autenticado).
  root "dashboard#index"

  # Itens da sidebar — placeholders da Fundação (Fase 1).
  # O domínio real (clientes/projetos/tarefas/demandas) chega na Fase 2+.
  # Clientes + Contatos aninhados (F2.1).
  resources :clients do
    resources :contacts, only: %i[new create edit update destroy]
  end
  resources :projects
  resources :tasks
  resources :demands do
    post :convert, on: :member
  end
  resources :time_entries

  # F3.UI.1 — console read-only de validação da Fase 3 (somente leitura).
  resources :conversations, only: %i[index show]
  resources :sync_runs, only: %i[index show]

  get "settings", to: "pages#placeholder", as: :settings
end
