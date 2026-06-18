class ConversationTurnRef < ApplicationRecord
  # Ponteiro para um turno no sessions.jsonl (offset/linha), SEM conteúdo. ADR-021.
  # Nunca persiste text/tool_input/payload — apenas localização + projeção leve (role/ts).
  belongs_to :turn_source
  belongs_to :conversation

  validates :thread_id, presence: true
  validates :line_no, numericality: { only_integer: true, greater_than: 0 }
  validates :byte_offset, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
