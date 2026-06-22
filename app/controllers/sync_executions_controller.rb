# PB-015 — dispara a sincronização operacional de conversas.
# Cria uma SyncExecution (status queued) e enfileira o job em background. Não recebe
# nem aceita paths/comandos do usuário — o serviço lê apenas o diretório fixo
# allowlisted (/normalized). Bloqueia nova solicitação se já houver execução ativa.
class SyncExecutionsController < ApplicationController
  def create
    authorize SyncExecution

    if SyncExecution.active?
      redirect_to sync_runs_path, alert: "Já existe uma sincronização em andamento."
      return
    end

    # PB-016a — `only_import` pula a coleta (pipeline) e só importa o output atual.
    only_import = params[:only_import].to_s == "1"
    trigger = only_import ? "manual_import" : "manual"
    execution = SyncExecution.new(status: "queued", trigger: trigger, requested_by_id: current_user.id)
    if execution.save
      SyncConversationsJob.perform_later(execution.id, skip_pipeline: only_import)
      redirect_to sync_runs_path, notice: "Sincronização enfileirada. Acompanhe o status abaixo."
    else
      # Índice único de execução ativa pode recusar em corrida — trata como concorrência.
      redirect_to sync_runs_path, alert: "Não foi possível enfileirar agora; verifique se há uma sincronização em andamento."
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to sync_runs_path, alert: "Já existe uma sincronização em andamento."
  end
end
