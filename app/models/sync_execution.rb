# PB-015 — execução operacional agregada de sincronização de conversas.
# Orquestra (na ordem) ImportSummaries + BuildConversationTurnRefs; cada etapa
# continua gerando seu próprio SyncRun (semântica inalterada). Esta linha apenas
# agrega status/tempos/erro para a UI, sem confundir-se com um SyncRun individual.
class SyncExecution < ApplicationRecord
  STATUSES = %w[queued running ok partial error].freeze
  ACTIVE = %w[queued running].freeze

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

  def duration_seconds
    return nil unless started_at && finished_at

    (finished_at - started_at).to_i
  end
end
