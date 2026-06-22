# PB-016a — página de Configurações do Omni. Por ora hospeda o agendador de
# importação (decisão de produto: o agendamento mora em Configurações). Read-only
# aqui; a edição é feita pelo SyncSchedulesController (resource :sync_schedule).
class SettingsController < ApplicationController
  def show
    @schedule = SyncSchedule.current
  end
end
