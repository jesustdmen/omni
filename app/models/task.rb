class Task < ApplicationRecord
  # Mantém a coluna `type` por paridade com o RepoA, sem ativar STI.
  self.inheritance_column = :_type_disabled

  # Lista fechada confirmada no validator do RepoA (server/src/validators/tasks.ts).
  TYPES = %w[support question implementation development commercial].freeze

  belongs_to :client
  belongs_to :project, optional: true
  has_many :time_entries, dependent: :destroy

  # status string + Rails enum (default todo); CHECK no banco garante os valores.
  enum :status, {
    pending: "pending",
    todo: "todo",
    in_progress: "in_progress",
    done: "done",
    canceled: "canceled"
  }, default: "todo", validate: true

  validates :title, presence: true
  validates :type, presence: true, inclusion: { in: TYPES }
  validates :status, presence: true
  validate :project_belongs_to_same_client

  # Soma read-only das durações dos apontamentos desta tarefa (F2.5).
  def total_duration
    time_entries.sum(:duration)
  end

  private

  def project_belongs_to_same_client
    return if project.blank? || client.blank?

    errors.add(:project, "deve pertencer ao mesmo cliente da tarefa") if project.client_id != client_id
  end
end
