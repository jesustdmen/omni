# PB-020 (Triagem) — atividade de 2º nível de uma conversa, como RASCUNHO.
#
# Revisável pelo humano até decisão (Confirmada/Descartada). NÃO cria Task/TimeEntry,
# NÃO toca ConversationLink. A origem pode ser `manual` (humano) ou `ia_local`
# (sugestão do Ollama/Gemma4 — sempre nasce como Rascunho; a confirmação é humana).
# Chaves internas em inglês por convenção; rótulos PT-BR via *_LABELS.
class ConversationActivityDraft < ApplicationRecord
  STATUSES = %w[draft confirmed discarded].freeze
  SOURCES  = %w[manual ia_local].freeze
  # Rótulos PT-BR exibidos na UI (chave interna não vaza para a tela).
  STATUS_LABELS = { "draft" => "Rascunho", "confirmed" => "Confirmada", "discarded" => "Descartada" }.freeze
  SOURCE_LABELS = { "manual" => "Manual", "ia_local" => "IA local" }.freeze

  belongs_to :conversation
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :title, with: ->(value) { value.to_s.strip }

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :ordered, -> { order(:position, :created_at, :id) }

  def status_label = STATUS_LABELS.fetch(status, status)
  def source_label = SOURCE_LABELS.fetch(source, source)
  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def discarded? = status == "discarded"
  def ia_local? = source == "ia_local"
end
