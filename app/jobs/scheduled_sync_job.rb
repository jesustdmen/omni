# PB-016a — disparo AGENDADO da sincronização (sem Tarefa do Windows).
# Recorrente no SolidQueue (config/recurring.yml, a cada 1 min): verifica a
# configuração singleton (SyncSchedule); se habilitada e vencida, e não houver
# execução ativa, cria uma SyncExecution(trigger: "scheduled") e enfileira o
# SyncConversationsJob — o MESMO fluxo do botão manual (coleta + importação).
#
# Tolerante a concorrência: o índice único de execução ativa impede 2 ativas; um
# RecordNotUnique aqui é benigno (já há uma rodando) e é silenciado.
class ScheduledSyncJob < ApplicationJob
  queue_as :default

  def perform
    schedule = SyncSchedule.current
    return unless schedule.due?
    return if SyncExecution.active?

    execution = SyncExecution.create!(status: "queued", trigger: "scheduled")
    schedule.update!(last_enqueued_at: Time.current)
    SyncConversationsJob.perform_later(execution.id)
  rescue ActiveRecord::RecordNotUnique
    # Já existe uma execução ativa (corrida com outro disparo) — nada a fazer.
    nil
  end
end
