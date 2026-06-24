class Project < ApplicationRecord
  belongs_to :client
  has_many :tasks, dependent: :nullify
  # PB-019b — contratos especializados por projeto. FK ON DELETE NULLIFY (excluir o
  # projeto desvincula o contrato, que passa a valer como geral do cliente).
  has_many :contracts, dependent: :nullify

  # PB-018 — status configurável (tabela `configurable_statuses`, entity_type='project').
  # A coluna `status` (string) guarda a KEY; rótulo/cor/opções vêm da tabela.
  # `status_entity` é constante ('project'), travada por CHECK + readonly — viabiliza
  # a FK composta (status_entity, status) -> configurable_statuses(entity_type, key).
  STATUS_ENTITY = "project".freeze
  attr_readonly :status_entity

  # Default em memória (espelha o default do banco) para satisfazer a validação
  # de presença em registros novos.
  attribute :status, :string, default: "planning"

  scope :ordered, -> { order(:name, :id) }

  validates :name, presence: true
  validates :status, presence: true
  validate :status_is_assignable
  validate :end_not_before_start

  # Substitui o antigo `Project::STATUSES` (lista fixa removida na PB-018).
  def self.status_keys
    ConfigurableStatus.keys_for(STATUS_ENTITY)
  end

  def self.status_key?(value)
    value.present? && status_keys.include?(value.to_s)
  end

  def status_label
    ConfigurableStatus.label_for(STATUS_ENTITY, status)
  end

  private

  # PB-018 — mesmo critério da Task: status deve existir para 'project'; valores
  # novos exigem status ativo; valor já persistido inalterado é aceito mesmo inativo.
  def status_is_assignable
    return if status.blank?

    row = ConfigurableStatus.for_entity(STATUS_ENTITY).find_by(key: status)
    if row.nil?
      errors.add(:status, "não é um status válido de projeto")
    elsif !row.active? && status_changed?
      errors.add(:status, "está inativo e não pode ser atribuído")
    end
  end

  def end_not_before_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "não pode ser anterior à data de início") if end_date < start_date
  end
end
