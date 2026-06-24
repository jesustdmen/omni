# PB-019b — Contrato da frente comercial (ADR-025).
# Pertence a Empresa Prestadora + Cliente; Projeto é OPCIONAL (quando presente,
# especializa o contrato — prioridade sobre o geral do cliente no cálculo futuro).
# Nesta fatia: só modalidade `hourly` (com `hourly_rate` obrigatório > 0). Status
# fixo (enum simples). NÃO grava nada em TimeEntry; cálculo/fechamento são futuros.
class Contract < ApplicationRecord
  MODALITIES = %w[hourly].freeze
  STATUSES = %w[draft active suspended ended].freeze
  STATUS_LABELS = {
    "draft" => "Rascunho", "active" => "Ativo",
    "suspended" => "Suspenso", "ended" => "Encerrado"
  }.freeze

  belongs_to :provider_company
  belongs_to :client
  belongs_to :project, optional: true

  attribute :modality, :string, default: "hourly"
  attribute :status, :string, default: "draft"

  validates :modality, inclusion: { in: MODALITIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :start_date, presence: true
  validates :hourly_rate, presence: true, numericality: { greater_than: 0 }
  validate :end_not_before_start
  validate :project_belongs_to_client
  validate :no_overlap

  scope :ordered, -> { order(start_date: :desc, id: :desc) }
  # "Ocupa período" — contratos encerrados não bloqueiam novos (histórico).
  scope :occupying, -> { where.not(status: "ended") }

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  def general?
    project_id.nil?
  end

  # Rótulo do período de vigência para exibição (fim vazio = aberto).
  def period_label
    [ start_date, end_date ].compact.map { |d| d.strftime("%d/%m/%Y") }.join(" → ").presence
  end

  private

  def end_not_before_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "não pode ser anterior à data de início") if end_date < start_date
  end

  def project_belongs_to_client
    return if project.blank? || client.blank?

    errors.add(:project, "deve pertencer ao mesmo cliente do contrato") if project.client_id != client_id
  end

  # PB-019b — sobreposição (ADR-025):
  #  - NÃO permite 2 contratos GERAIS (project_id nil) sobrepostos p/ mesma prestadora+cliente;
  #  - NÃO permite 2 contratos do MESMO projeto sobrepostos;
  #  - PERMITE geral + de projeto no mesmo período (escopos distintos).
  # Contratos `ended` não ocupam período (histórico). Implementado em Rails — sem
  # constraint EXCLUDE no banco nesta fatia (risco residual de concorrência: ADR-025).
  def no_overlap
    return if provider_company_id.blank? || client_id.blank? || start_date.blank?
    return if status == "ended" # um contrato encerrado não conflita com nada

    scope = Contract.occupying
                    .where(provider_company_id: provider_company_id, client_id: client_id, project_id: project_id)
                    .where.not(id: id)

    conflicting = scope.any? { |other| periods_overlap?(other) }
    return unless conflicting

    msg = general? ? "Já existe um contrato geral vigente para esta empresa prestadora e cliente no período." :
                     "Já existe um contrato vigente para este projeto no período."
    errors.add(:base, msg)
  end

  # Interseção de [start, end||∞] com o outro contrato:
  #   A.start <= B.end(∞)  &&  B.start <= A.end(∞)
  def periods_overlap?(other)
    a_start = start_date
    a_end   = end_date        # nil = ∞ (vigência aberta)
    b_start = other.start_date
    b_end   = other.end_date  # nil = ∞

    left  = a_end.nil? || b_start <= a_end
    right = b_end.nil? || a_start <= b_end
    left && right
  end
end
