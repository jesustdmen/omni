# PB-015 — execução operacional agregada de sincronização de conversas.
# Orquestra (na ordem) ImportSummaries + BuildConversationTurnRefs; cada etapa
# continua gerando seu próprio SyncRun (semântica inalterada). Esta linha apenas
# agrega status/tempos/erro para a UI, sem confundir-se com um SyncRun individual.
class SyncExecution < ApplicationRecord
  STATUSES = %w[queued running ok partial error].freeze
  ACTIVE = %w[queued running].freeze
  # Etapas operacionais esperadas, na ordem (PB-015) — base do indicador de progresso.
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

  # --- progresso por etapa (PB-015) ---------------------------------------
  def steps_total
    STEPS.size
  end

  # Etapas concluídas = SyncRuns desta execução cujo label é uma etapa conhecida.
  def steps_done
    done = sync_runs.where(source_label: STEPS.map { |s| s[:label] }).distinct.count(:source_label)
    # Execução concluída conta como todas as etapas (cobre status sem todos os runs).
    active? ? done : [ done, steps_total ].max
  end

  # Etapa em andamento (a primeira ainda não registrada como SyncRun), ou nil.
  def current_step_title
    return nil unless status == "running"

    done_labels = sync_runs.pluck(:source_label)
    pending = STEPS.find { |s| done_labels.exclude?(s[:label]) }
    pending&.dig(:title) || STEPS.last[:title]
  end

  def progress_percent
    case status
    when "queued"             then 0
    when "ok", "partial", "error" then 100
    else ((steps_done.to_f / steps_total) * 100).round
    end
  end
end
