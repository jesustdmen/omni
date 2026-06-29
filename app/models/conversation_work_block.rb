# PB-020d (Triagem) — rascunho de BLOCO DE TRABALHO (turno/dia) de uma conversa.
#
# Unidade entre a atividade macro e o TimeEntry. A janela de tempo é EVIDÊNCIA/SUGESTÃO
# (start/end opcionais e editáveis) e a `duration_seconds` é EDITÁVEL pelo humano — não
# derivada (timestamps são evidência, não verdade absoluta). NÃO cria Task/TimeEntry,
# NÃO toca ConversationLink, NÃO chama IA. Microatividades = snapshot textual (summary/notes).
# Chaves internas em inglês por convenção; rótulos PT-BR via *_LABELS.
class ConversationWorkBlock < ApplicationRecord
  DAY_PERIODS = %w[manha tarde noite].freeze
  KINDS = %w[execution gap].freeze
  STATUSES = %w[draft confirmed discarded].freeze
  SOURCES  = %w[manual ia_local].freeze

  DAY_PERIOD_LABELS = { "manha" => "Manhã", "tarde" => "Tarde", "noite" => "Noite" }.freeze
  KIND_LABELS   = { "execution" => "Execução", "gap" => "Gap" }.freeze
  STATUS_LABELS = { "draft" => "Rascunho", "confirmed" => "Confirmada", "discarded" => "Descartada" }.freeze
  SOURCE_LABELS = { "manual" => "Manual", "ia_local" => "IA local" }.freeze

  belongs_to :conversation
  belongs_to :client, optional: true
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :summary, :notes, :external_evidence_note, with: ->(value) { value.to_s.strip.presence }

  validates :period_date, presence: true
  validates :day_period, presence: true, inclusion: { in: DAY_PERIODS }
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :end_not_before_start
  # PB-020d — conversa PESSOAL não participa da avaliação de trabalho (decisão de produto):
  # não gera/edita bloco. Bloqueia create e update; destroy (limpeza) segue permitido.
  validate :conversation_not_personal

  scope :ordered, -> { order(:period_date, :position, :created_at, :id) }

  def day_period_label = DAY_PERIOD_LABELS.fetch(day_period, day_period)
  def kind_label = KIND_LABELS.fetch(kind, kind)
  def status_label = STATUS_LABELS.fetch(status, status)
  def source_label = SOURCE_LABELS.fetch(source, source)
  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def discarded? = status == "discarded"
  def gap? = kind == "gap"
  def ia_local? = source == "ia_local"

  private

  # Janela coerente quando ambos informados; mas tempo é evidência (não obriga preencher).
  def end_not_before_start
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "deve ser igual ou posterior ao início") if end_time < start_time
  end

  # Backstop de modelo: conversa pessoal não gera/edita bloco de trabalho.
  def conversation_not_personal
    return unless conversation&.personal?

    errors.add(:base, "Conversa marcada como pessoal. Blocos de trabalho não são gerados para conversas pessoais.")
  end
end
