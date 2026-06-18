class TurnSource < ApplicationRecord
  # Identidade de uma versão indexada do sessions.jsonl (fingerprint). ADR-021.
  # NÃO guarda conteúdo de turnos — apenas metadados do arquivo.
  STATUSES = %w[pending ok partial stale error].freeze

  has_many :conversation_turn_refs, dependent: :destroy

  validates :source_label, :source_file, :content_hash, :schema_version, presence: true
  validates :size_bytes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
end
