class Task < ApplicationRecord
  # Mantém a coluna `type` por paridade com o RepoA, sem ativar STI.
  self.inheritance_column = :_type_disabled

  # Lista fechada confirmada no validator do RepoA (server/src/validators/tasks.ts).
  TYPES = %w[support question implementation development commercial].freeze

  belongs_to :client
  belongs_to :project, optional: true
  has_many :time_entries, dependent: :destroy
  # delete_all: a tarefa some → não há por que recomputar counters dela (sem callbacks).
  has_many :conversation_links, dependent: :delete_all
  has_many :conversations, through: :conversation_links

  # status string + Rails enum (default todo); CHECK no banco garante os valores.
  enum :status, {
    pending: "pending",
    todo: "todo",
    in_progress: "in_progress",
    done: "done",
    canceled: "canceled"
  }, default: "todo", validate: true

  validates :title, presence: true
  validates :type, presence: true, inclusion: { in: TYPES }
  validates :status, presence: true
  validate :project_belongs_to_same_client

  # Soma read-only das durações dos apontamentos desta tarefa (F2.5).
  def total_duration
    time_entries.sum(:duration)
  end

  # F4: recomputa os counters de conversa a partir dos vínculos PRIMARY de
  # conversas NÃO-personal (ADR-013). Idempotente; usa update_columns (sem callbacks/validações).
  def recompute_conversation_counters!
    primary = conversation_links.where(link_type: "primary")
                                .joins(:conversation).where(conversations: { personal: false })
    update_columns(
      conversation_count: primary.count,
      last_conversation_at: primary.maximum("conversations.last_ts")
    )
  end

  private

  def project_belongs_to_same_client
    return if project.blank? || client.blank?

    errors.add(:project, "deve pertencer ao mesmo cliente da tarefa") if project.client_id != client_id
  end
end
