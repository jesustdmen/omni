class Conversation < ApplicationRecord
  # user_id/personal são preparação (ADR-013/014); sem enforcement de escopo nesta fase.
  belongs_to :user, optional: true

  validates :thread_id, presence: true, uniqueness: true
  validates :message_count, :user_turns, :assistant_turns, :tool_calls,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
