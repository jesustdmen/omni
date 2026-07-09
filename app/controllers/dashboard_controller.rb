class DashboardController < ApplicationController
  # Apenas leitura de dados já existentes no domínio, para os cards do dashboard
  # (ADR-026/PB-023a — prova visual dos tokens). Sem lógica de negócio nova.
  def index
    @clients_count  = Client.count
    @projects_count = Project.count
    @tasks_count    = Task.count
    @demands_count  = Demand.count
    @pending_demands_count = Demand.pending.count
    @recent_tasks = Task.includes(:client).order(created_at: :desc).limit(6)

    # Card "Hoje" — dia operacional em Brasília (ADR-023: `date` já é derivada
    # no fuso local). Timers em andamento não somam (duration = 0 até parar).
    today = Date.current
    @today_seconds = TimeEntry.where(is_running: false, date: today).sum(:duration)
    @today_entries_count = TimeEntry.where(date: today).count

    # Demandas pendentes mais urgentes (prioridade alta primeiro, depois recência).
    @pending_demands = Demand.pending.includes(:client)
                             .order(Arel.sql("CASE priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END"),
                                    created_at: :desc)
                             .limit(3)
  end
end
