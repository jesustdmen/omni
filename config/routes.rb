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
  resources :tasks do
    # PB-003a — iniciar timer a partir da tarefa (contexto explícito na URL).
    resource :timer, only: %i[create], controller: "task_timers"
  end
  resources :demands do
    post :convert, on: :member
  end
  resources :time_entries do
    patch :stop, on: :member # PB-003a — parar um timer em andamento.
    get :running, on: :collection # PB-003c — lista global de timers em andamento.
  end

  # F3.UI.1 — console read-only de validação da Fase 3 (somente leitura).
  # F4 — vínculo manual conversa↔tarefa (links aninhados; create/destroy).
  resources :conversations, only: %i[index show] do
    resources :links, controller: "conversation_links", only: %i[create destroy]
    # F5.3 (UI-10) — criar tarefa a partir da conversa (vínculo primary/manual automático).
    resources :tasks, controller: "conversation_tasks", only: %i[new create]
  end
  resources :sync_runs, only: %i[index show]

  get "settings", to: "pages#placeholder", as: :settings
end
