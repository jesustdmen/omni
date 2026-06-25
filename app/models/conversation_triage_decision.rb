# PB-020 (Triagem persistida mínima) — decisão HUMANA de triagem de uma conversa.
#
# Tabela `conversation_triages` (1:1). O nome do model é ConversationTriageDecision
# para NÃO colidir com o service `ConversationTriage` (estado efetivo/derivado).
#
# Contratos (ver docs/PB-020 §D0):
#   - status = FLUXO de revisão (chaves internas open|reviewed|ignored = Aberta|Revisada|Ignorada;
#     lista permitida; nunca representa cliente/pessoal/vinculada);
#   - cliente/projeto confirmado são CAMPOS PRÓPRIOS (confirmed_client/confirmed_project), não status;
#   - privacidade NÃO mora aqui: continua em conversations.personal;
#   - "linked" NÃO mora aqui: segue derivado de ConversationLink.
class ConversationTriageDecision < ApplicationRecord
  self.table_name = "conversation_triages"

  STATUSES = %w[open reviewed ignored].freeze

  belongs_to :conversation
  belongs_to :confirmed_client, class_name: "Client", optional: true
  belongs_to :confirmed_project, class_name: "Project", optional: true
  belongs_to :triaged_by, class_name: "User", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :conversation_id, uniqueness: true
  validate :project_belongs_to_confirmed_client

  def client_confirmed? = confirmed_client_id.present?

  private

  # Coerência: se cliente E projeto foram confirmados, o projeto tem que ser do cliente.
  # (Project belongs_to :client — regra local clara; não inventa nada além disso.)
  def project_belongs_to_confirmed_client
    return if confirmed_project.nil?
    return if confirmed_client_id.present? && confirmed_project.client_id == confirmed_client_id

    errors.add(:confirmed_project, "deve pertencer ao cliente confirmado")
  end
end
