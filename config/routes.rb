Rails.application.routes.draw do
  devise_for :users

  # Health check (load balancers / uptime).
  get "up" => "rails/health#show", as: :rails_health_check

  # Raiz: dashboard (autenticado).
  root "dashboard#index"

  # Itens da sidebar — placeholders da Fundação (Fase 1).
  # O domínio real (clientes/projetos/tarefas/demandas) chega na Fase 2+.
  get "clients",  to: "pages#placeholder", as: :clients
  get "projects", to: "pages#placeholder", as: :projects
  get "tasks",    to: "pages#placeholder", as: :tasks
  get "demands",  to: "pages#placeholder", as: :demands
  get "settings", to: "pages#placeholder", as: :settings
end
