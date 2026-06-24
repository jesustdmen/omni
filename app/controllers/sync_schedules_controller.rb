# PB-016a — configura o agendamento interno da sincronização (singleton).
# Liga/desliga + intervalo (minutos, allowlist). Sem Tarefa do Windows: o disparo
# é feito pelo ScheduledSyncJob (recorrente). Não recebe paths/comandos.
class SyncSchedulesController < ApplicationController
  def update
    schedule = SyncSchedule.current
    authorize schedule

    enabled = ActiveModel::Type::Boolean.new.cast(params.dig(:sync_schedule, :enabled))
    interval = params.dig(:sync_schedule, :interval_minutes).to_i
    # Allowlist de intervalos; valor inválido mantém o atual.
    interval = schedule.interval_minutes unless SyncSchedule::INTERVAL_OPTIONS.include?(interval)

    if schedule.update(enabled: enabled, interval_minutes: interval)
      msg = enabled ? "Agendamento ativado (a cada #{schedule.interval_label})." : "Agendamento desativado."
      redirect_to settings_sync_path, notice: msg
    else
      redirect_to settings_sync_path, alert: "Não foi possível salvar o agendamento."
    end
  end
end
