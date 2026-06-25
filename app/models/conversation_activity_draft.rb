# PB-020 (Triagem) — atividade de 2º nível de uma conversa, como RASCUNHO manual.
#
# Revisável pelo humano até decisão (Confirmada/Descartada). NÃO cria Task/TimeEntry,
# NÃO toca ConversationLink, NÃO chama IA. `source` interno só `manual` nesta fase
# (chave interna em inglês por convenção; rótulos PT-BR via STATUS_LABELS).
class ConversationActivityDraft < ApplicationRecord
  STATUSES = %w[draft confirmed discarded].freeze
  SOURCES  = %w[manual].freeze
  # Rótulos PT-BR exibidos na UI (chave interna não vaza para a tela).
  STATUS_LABELS = { "draft" => "Rascunho", "confirmed" => "Confirmada", "discarded" => "Descartada" }.freeze

  belongs_to :conversation
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :ordered, -> { order(:position, :created_at, :id) }

  def status_label = STATUS_LABELS.fetch(status, status)
  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def discarded? = status == "discarded"
end
