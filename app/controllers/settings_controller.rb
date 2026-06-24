# Configurações do Omni — hub com sub-páginas por domínio:
#   /settings        → índice (cards de acesso)
#   /settings/sync   → agendador de importação (PB-016b)
#   /settings/status → status configurável de Tarefas/Projetos (PB-018)
#   /settings/provider-companies → CRUD de Empresa Prestadora (PB-019a; controller próprio)
# Read-only aqui; cada escrita tem seu controller com Pundit.
class SettingsController < ApplicationController
  def index
    # Contagens/resumos para os cards do hub (leves).
    @schedule = SyncSchedule.current
    @task_statuses_count = ConfigurableStatus.for_entity("task").count
    @project_statuses_count = ConfigurableStatus.for_entity("project").count
    @provider_companies_count = ProviderCompany.count
  end

  def sync
    @schedule = SyncSchedule.current
  end

  def status
    @task_statuses = ConfigurableStatus.for_entity("task").ordered.to_a
    @project_statuses = ConfigurableStatus.for_entity("project").ordered.to_a
    @new_status = ConfigurableStatus.new
  end
end
