# PB-015 — processa a sincronização operacional de conversas em background
# (SolidQueue). Não recebe paths/comandos: a SyncExecution é criada pelo controller
# e o serviço lê apenas do diretório fixo/allowlisted. Sem retentativa automática
# (uma falha fica registrada na SyncExecution; o operador re-dispara pela UI).
class SyncConversationsJob < ApplicationJob
  queue_as :default

  def perform(sync_execution_id)
    execution = SyncExecution.find_by(id: sync_execution_id)
    return if execution.nil? || !execution.active?

    Sync::RunConversationsSync.call(execution: execution)
  end
end
