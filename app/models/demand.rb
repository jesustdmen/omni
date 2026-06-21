class Demand < ApplicationRecord
  # Listas fechadas confirmadas no validator do RepoA (server/src/validators/demands.ts).
  ORIGINS = %w[phone email meeting chat whatsapp other].freeze
  PRIORITIES = %w[low medium high].freeze

  belongs_to :client, optional: true
  # PB-004c — tarefa criada a partir desta demanda (0 ou 1). Não destrói a tarefa
  # ao excluir a demanda: a FK é RESTRICT e a app bloqueia (ver DemandsController).
  has_one :converted_task, class_name: "Task", foreign_key: :demand_id, dependent: :restrict_with_error, inverse_of: :origin_demand

  enum :status, { pending: "pending", converted: "converted" }, default: "pending", validate: true

  validates :title, presence: true
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :status, presence: true
end
