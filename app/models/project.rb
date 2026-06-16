class Project < ApplicationRecord
  belongs_to :client

  # Default em memória (espelha o default do banco) para satisfazer a validação
  # de presença em registros novos.
  attribute :status, :string, default: "planning"

  validates :name, presence: true
  validates :status, presence: true
  validate :end_not_before_start

  private

  def end_not_before_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "não pode ser anterior à data de início") if end_date < start_date
  end
end
