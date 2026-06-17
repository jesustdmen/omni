class Conversation < ApplicationRecord
  # user_id/personal são preparação (ADR-013/014); sem enforcement de escopo nesta fase.
  belongs_to :user, optional: true
  # destroy: ao excluir uma conversa, remove os links e recomputa as tarefas afetadas.
  has_many :conversation_links, dependent: :destroy
  has_many :tasks, through: :conversation_links

  validates :thread_id, presence: true, uniqueness: true
  validates :message_count, :user_turns, :assistant_turns, :tool_calls,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
