# PB-004b — item de checklist de uma tarefa. Persistente, simples (sem position,
# sem subtarefas, sem prazo/responsável). Ordenação explícita por created_at, id
# (sem default_scope).
class ChecklistItem < ApplicationRecord
  belongs_to :task

  # Remove espaços externos antes de validar (rejeita conteúdo só-espaços/vazio).
  normalizes :content, with: ->(value) { value.to_s.strip }

  validates :content, presence: true
  validates :completed, inclusion: { in: [ true, false ] }

  scope :ordered, -> { order(:created_at, :id) }
end
