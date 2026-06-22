# PB-015 — execução operacional agregada de sincronização de conversas.
# Orquestra (na ordem) ImportSummaries + BuildConversationTurnRefs; cada etapa
# continua gerando seu próprio SyncRun (semântica inalterada). Esta linha apenas
# agrega status/tempos/erro para a UI, sem confundir-se com um SyncRun individual.
class SyncExecution < ApplicationRecord
  STATUSES = %w[queued running ok partial error].freeze
  ACTIVE = %w[queued running].freeze

  # PB-016a — etapas da sincronização COMPLETA (pipeline + importação), na ordem;
  # base do indicador de progresso por etapa (via `current_step`). "collecting" só
  # ocorre com o pipeline interno habilitado; sem ele, começa em "verifying" (PB-015).
  STEP_FLOW = [
    { key: "collecting", title: "Coletando e normalizando (pipeline)" },
    { key: "verifying",  title: "Verificando arquivos" },
    { key: "importing",  title: "Importando metadados" },
    { key: "indexing",   title: "Indexando turnos" }
  ].freeze
  STEP_TITLES = STEP_FLOW.to_h { |s| [ s[:key], s[:title] ] }.freeze

  # Compat PB-015: etapas com SyncRun próprio (contagem de runs concluídos).
  STEPS = [
    { label: "summaries.jsonl", title: "Conversas (metadados)" },
    { label: "sessions.jsonl",  title: "Índice de turnos" }
  ].freeze

  has_many :sync_runs, dependent: :nullify

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :trigger, presence: true

  scope :active, -> { where(status: ACTIVE) }
  scope :recent, -> { order(created_at: :desc) }

  def self.active?
    active.exists?
  end

  def active?
    ACTIVE.include?(status)
  end

  def queued?
    status == "queued"
  end

  def running?
    status == "running"
  end

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end

  # --- progresso por etapa (PB-016a — baseado em `current_step`) -----------
  def steps_total
    STEP_FLOW.size
  end

  # Índice (1-based) da etapa corrente no fluxo; 0 quando ainda não começou.
  def step_index
    idx = STEP_FLOW.index { |s| s[:key] == current_step }
    idx ? idx + 1 : 0
  end

  # Etapas concluídas para o indicador (a corrente conta como em andamento).
  def steps_done
    return steps_total unless active? # concluída/erro: barra cheia

    [ step_index - 1, 0 ].max
  end

  # Etapa em andamento (rótulo amigável), ou nil.
  def current_step_title
    return nil unless running?

    STEP_TITLES[current_step] || STEP_TITLES.values.first
  end

  def progress_percent
    case status
    when "queued"                 then 0
    when "ok", "partial", "error" then 100
    else
      return 0 if step_index.zero?

      ((step_index.to_f / steps_total) * 100).round
    end
  end
end
