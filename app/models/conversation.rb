class Conversation < ApplicationRecord
  # user_id/personal são preparação (ADR-013/014); sem enforcement de escopo nesta fase.
  belongs_to :user, optional: true
  # destroy: ao excluir uma conversa, remove os links e recomputa as tarefas afetadas.
  has_many :conversation_links, dependent: :destroy
  has_many :tasks, through: :conversation_links
  # PB-020 (Triagem persistida mínima) — decisão humana 1:1 (status/cliente/projeto confirmado).
  # FK ON DELETE CASCADE no banco; dependent: :destroy mantém o ORM coerente.
  has_one :triage, class_name: "ConversationTriageDecision", dependent: :destroy
  # PB-020 (Triagem) — atividades de 2º nível (rascunhos manuais). FK CASCADE no banco;
  # delete_all: itens sem callbacks, removidos junto com a conversa.
  has_many :activity_drafts, class_name: "ConversationActivityDraft", dependent: :delete_all
  # PB-020d (Triagem) — blocos de trabalho (rascunhos por turno/dia). FK CASCADE no banco;
  # delete_all: itens sem callbacks, removidos junto com a conversa.
  has_many :work_blocks, class_name: "ConversationWorkBlock", dependent: :delete_all

  validates :thread_id, presence: true, uniqueness: true
  validates :message_count, :user_turns, :assistant_turns, :tool_calls,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
