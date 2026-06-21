class Project < ApplicationRecord
  belongs_to :client
  has_many :tasks, dependent: :nullify

  # PB-007 — lista fechada de status (espelha o CHECK no banco) + labels PT-BR.
  STATUSES = %w[planning in_progress completed on_hold].freeze
  STATUS_LABELS = {
    "planning" => "Planejamento", "in_progress" => "Em andamento",
    "completed" => "Concluído", "on_hold" => "Em espera"
  }.freeze

  # Default em memória (espelha o default do banco) para satisfazer a validação
  # de presença em registros novos.
  attribute :status, :string, default: "planning"

  scope :ordered, -> { order(:name, :id) }

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :end_not_before_start

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  private

  def end_not_before_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "não pode ser anterior à data de início") if end_date < start_date
  end
end
