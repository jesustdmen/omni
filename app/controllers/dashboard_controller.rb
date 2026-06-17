class DashboardController < ApplicationController
  # Apenas leitura de dados já existentes no domínio, para os cards do dashboard
  # (F2.UI). Sem lógica de negócio nova; conversas/triagem continuam placeholder.
  def index
    @clients_count  = Client.count
    @projects_count = Project.count
    @tasks_count    = Task.count
    @demands_count  = Demand.count
    @pending_demands_count = Demand.pending.count
    @recent_tasks = Task.includes(:client).order(created_at: :desc).limit(6)
  end
end
