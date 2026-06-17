class ConversationLink < ApplicationRecord
  LINK_TYPES = %w[primary mention].freeze
  ORIGINS = %w[manual auto suggestion].freeze

  belongs_to :conversation
  belongs_to :task
  belongs_to :created_by, class_name: "User", optional: true

  validates :link_type, presence: true, inclusion: { in: LINK_TYPES }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :conversation_id, uniqueness: { scope: %i[task_id link_type] }
  validate :single_primary_per_conversation

  # Counters mantidos transacionalmente (mesma transação do save/destroy do link).
  after_create :sync_task_counters
  after_destroy :sync_task_counters

  private

  def single_primary_per_conversation
    return unless link_type == "primary"

    clash = ConversationLink.where(conversation_id: conversation_id, link_type: "primary").where.not(id: id)
    errors.add(:link_type, "já existe um vínculo primário para esta conversa") if clash.exists?
  end

  def sync_task_counters
    task&.recompute_conversation_counters!
  end
end
