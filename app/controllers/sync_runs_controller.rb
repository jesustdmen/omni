class SyncRunsController < ApplicationController
  # F3.UI.1 — console SOMENTE LEITURA de validação da Fase 3.
  def index
    @sync_runs = policy_scope(SyncRun).order(created_at: :desc)
    # PB-015 — execução operacional agregada (para o painel de status/ação).
    @executions = SyncExecution.recent.limit(10)
    @active_execution = SyncExecution.active.order(created_at: :desc).first
    @last_execution = @executions.first
  end

  def show
    @sync_run = SyncRun.find(params[:id])
    authorize @sync_run
    @items = @sync_run.items.order(:line_number)
  end
end
