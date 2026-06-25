Rails.application.routes.draw do
  # PB-017 — uso single-user/somente-Admin: cadastro público desabilitado.
  # `skip: :registrations` remove TODAS as rotas de registro do Devise
  # (GET /users/sign_up, POST /users, /users/cancel, GET/PATCH/PUT/DELETE /users).
  # Sessão e recuperação de senha (recoverable) permanecem.
  devise_for :users, skip: [ :registrations ]

  # Health check (load balancers / uptime).
  get "up" => "rails/health#show", as: :rails_health_check

  # Raiz: dashboard (autenticado).
  root "dashboard#index"

  # Itens da sidebar — placeholders da Fundação (Fase 1).
  # O domínio real (clientes/projetos/tarefas/demandas) chega na Fase 2+.
  # Clientes + Contatos aninhados (F2.1).
  resources :clients do
    # PB-006 — a consulta de CNPJ é feita no navegador (ADR-022 addendum 2026-06-22);
    # não há mais proxy no servidor.
    resources :contacts, only: %i[new create edit update destroy]
  end
  resources :projects do
    post :duplicate, on: :member # PB-007 — duplica o projeto (campos autorizados).
  end
  resources :tasks do
    # PB-003a — iniciar timer a partir da tarefa (contexto explícito na URL).
    resource :timer, only: %i[create], controller: "task_timers"
    # PB-004b — checklist persistente (sempre escopado pela tarefa da URL).
    resources :checklist_items, only: %i[create update destroy]
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
    # PB-020 (Triagem persistida mínima) — decisão humana 1:1 (status + cliente/projeto confirmado).
    resource :triage, controller: "conversation_triages", only: %i[update]
  end
  # PB-013 — busca global (read-only) sobre os dados funcionais.
  get "search", to: "search#index"

  resources :sync_runs, only: %i[index show]
  # PB-015 — disparo da sincronização operacional (enfileira job; lê só /normalized).
  resources :sync_executions, only: %i[create]
  # PB-016a — configuração do agendamento interno (singleton; liga/desliga + intervalo).
  resource :sync_schedule, only: %i[update]

  # Configurações: hub com sub-páginas por domínio (sync, status, prestadoras).
  get "settings", to: "settings#index", as: :settings
  get "settings/sync", to: "settings#sync", as: :settings_sync       # PB-016b — agendador
  get "settings/status", to: "settings#status", as: :settings_status # PB-018 — status configurável

  # PB-018 — status configuráveis (Tarefas/Projetos) administrados em Configurações.
  # `entity_type` (task|project) vem como parâmetro de escopo para CRUD por entidade.
  resources :configurable_statuses, only: %i[create update destroy], path: "settings/statuses"

  # PB-019a — Empresa Prestadora (frente comercial; cadastro em Configurações,
  # padrão de CRUD do Omni: lista + páginas Nova/Editar).
  resources :provider_companies, except: %i[show], path: "settings/provider-companies"

  # PB-019b — Contratos (frente comercial; item próprio na sidebar).
  resources :contracts

  # PB-020a — Apuração de horas trabalhadas (read-only; sem contrato/valor).
  resources :work_time_reports, only: %i[index]

  # PB-020 (Triagem) — Inbox/Central de Triagem de conversas (read-only nesta fatia).
  get "triage", to: "triage#index", as: :triage
end
