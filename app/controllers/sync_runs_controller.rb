require "net/http"
require "json"
require "uri"

class SyncRunsController < ApplicationController
  # F3.UI.1 — console SOMENTE LEITURA de validação da Fase 3.
  def index
    @sync_runs = policy_scope(SyncRun).order(created_at: :desc)
    # PB-015 — execução operacional agregada (para o painel de status/ação).
    @executions = SyncExecution.recent.limit(10)
    @active_execution = SyncExecution.active.order(created_at: :desc).first
    @last_execution = @executions.first
    # PB-016a — a UI muda rótulos/ação conforme o pipeline interno está ligado.
    @pipeline_internal = Rails.application.config.x.run_pipeline_internally
    # PB-016a — configuração do agendamento (singleton) + estado do agente.
    @schedule = SyncSchedule.current
    @agent_online = @pipeline_internal && pipeline_agent_online?
  end

  def show
    @sync_run = SyncRun.find(params[:id])
    authorize @sync_run
    @items = @sync_run.items.order(:line_number)
  end

  private

  # PB-016a — estado do agente de pipeline (health rápido; nunca quebra a página).
  def pipeline_agent_online?
    url = Rails.application.config.x.pipeline_agent_url.to_s
    return false if url.blank?

    uri = URI.join(url, "/health")
    http = Net::HTTP.new(uri.host, uri.port)
    http.open_timeout = 2
    http.read_timeout = 2
    res = http.get(uri.request_uri)
    res.is_a?(Net::HTTPSuccess) && (JSON.parse(res.body)["ok"] == true)
  rescue StandardError
    false
  end
end
