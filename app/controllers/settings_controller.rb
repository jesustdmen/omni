# PB-016a — página de Configurações do Omni. Por ora hospeda o agendador de
# importação (decisão de produto: o agendamento mora em Configurações). Read-only
# aqui; a edição é feita pelo SyncSchedulesController (resource :sync_schedule).
class SettingsController < ApplicationController
  def show
    @schedule = SyncSchedule.current
    # PB-018 — status configuráveis por entidade (Tarefas/Projetos) para a seção
    # "Status" da página. Inclui inativos (admin enxerga tudo); ordenados por posição.
    @task_statuses = ConfigurableStatus.for_entity("task").ordered.to_a
    @project_statuses = ConfigurableStatus.for_entity("project").ordered.to_a
    @new_status = ConfigurableStatus.new
  end
end
