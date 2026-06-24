class Demand < ApplicationRecord
  # Listas fechadas confirmadas no validator do RepoA (server/src/validators/demands.ts).
  ORIGINS = %w[phone email meeting chat whatsapp other].freeze
  PRIORITIES = %w[low medium high].freeze
  # PB-018 (termos PT-BR) — rótulos de exibição (listas fixas, não configuráveis).
  ORIGIN_LABELS = {
    "phone" => "Telefone", "email" => "E-mail", "meeting" => "Reunião",
    "chat" => "Chat", "whatsapp" => "WhatsApp", "other" => "Outro"
  }.freeze
  PRIORITY_LABELS = { "low" => "Baixa", "medium" => "Média", "high" => "Alta" }.freeze

  def self.origin_label(value)
    ORIGIN_LABELS.fetch(value.to_s, value.to_s)
  end

  def self.priority_label(value)
    PRIORITY_LABELS.fetch(value.to_s, value.to_s)
  end

  def origin_label
    self.class.origin_label(origin)
  end

  def priority_label
    self.class.priority_label(priority)
  end

  belongs_to :client, optional: true
  # PB-004c — tarefa criada a partir desta demanda (0 ou 1). Não destrói a tarefa
  # ao excluir a demanda: a FK é RESTRICT e a app bloqueia (ver DemandsController).
  has_one :converted_task, class_name: "Task", foreign_key: :demand_id, dependent: :restrict_with_error, inverse_of: :origin_demand

  # PB-018 — Demanda permanece com status FIXO (não configurável): pending/converted.
  # Apenas adiciona rótulos PT-BR (Pendente/Convertida) p/ exibição. Os predicados
  # do enum (pending?/converted?) seguem em uso (views/serviços de conversão).
  enum :status, { pending: "pending", converted: "converted" }, default: "pending", validate: true
  STATUS_LABELS = { "pending" => "Pendente", "converted" => "Convertida" }.freeze

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  validates :title, presence: true
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :status, presence: true
end
