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
  # PB-020e — classificação MANUAL de gap (obrigatória para confirmar um gap; gap nunca
  # é cobrável). `fora_vscode` NÃO é gap nesta fatia: trabalho fora do chat pode ser
  # execução/evidência (teste em ERP, consulta em banco), não necessariamente pausa.
  GAP_KINDS = %w[pernoite almoco lanche outra_tarefa_cliente aguardando_cliente pausa indeterminado].freeze

  DAY_PERIOD_LABELS = { "manha" => "Manhã", "tarde" => "Tarde", "noite" => "Noite" }.freeze
  KIND_LABELS   = { "execution" => "Execução", "gap" => "Gap" }.freeze
  STATUS_LABELS = { "draft" => "Rascunho", "confirmed" => "Confirmada", "discarded" => "Descartada" }.freeze
  SOURCE_LABELS = { "manual" => "Manual", "ia_local" => "IA local" }.freeze
  GAP_KIND_LABELS = {
    "pernoite" => "Pernoite", "almoco" => "Almoço", "lanche" => "Lanche",
    "outra_tarefa_cliente" => "Outra tarefa do cliente", "aguardando_cliente" => "Aguardando cliente",
    "pausa" => "Pausa", "indeterminado" => "Indeterminado"
  }.freeze

  belongs_to :conversation
  belongs_to :client, optional: true
  belongs_to :project, optional: true
  belongs_to :task, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :summary, :notes, :external_evidence_note, :gap_kind, with: ->(value) { value.to_s.strip.presence }

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
  # PB-020e — regras de VALIDAÇÃO de tempo (confirmar = validar para o subtotal):
  # gap_kind só em gap e pela lista permitida; duração > 0 para confirmar; gap
  # confirmado exige classificação; validar tempo (execution confirmado) exige
  # cliente E tarefa. Erros em :base com frases PT-BR completas — full_messages
  # prefixaria o nome do atributo em inglês (o app não tem locale pt-BR).
  validate :gap_kind_rules
  validate :confirmation_rules

  scope :ordered, -> { order(:period_date, :position, :created_at, :id) }

  def day_period_label = DAY_PERIOD_LABELS.fetch(day_period, day_period)
  def kind_label = KIND_LABELS.fetch(kind, kind)
  def status_label = STATUS_LABELS.fetch(status, status)
  def source_label = SOURCE_LABELS.fetch(source, source)
  def gap_kind_label = GAP_KIND_LABELS.fetch(gap_kind, gap_kind)
  def draft? = status == "draft"
  def confirmed? = status == "confirmed"
  def discarded? = status == "discarded"
  def gap? = kind == "gap"
  def execution? = kind == "execution"
  def ia_local? = source == "ia_local"

  # PB-020e — só EXECUÇÃO confirmada entra no subtotal validado (gap nunca é cobrável).
  def counts_for_subtotal? = execution? && confirmed?

  # PB-020e — pendências que impedem confirmar este bloco (espelho das validações,
  # para a UI bloquear/explicar ANTES do submit). Vazio = pode confirmar.
  def validation_blockers
    blockers = []
    blockers << "duração deve ser maior que zero" unless duration_seconds.to_i.positive?
    if execution?
      blockers << "cliente é obrigatório para validar tempo" if client_id.blank?
      blockers << "tarefa é obrigatória para validar tempo" if task_id.blank?
    else
      blockers << "classifique o gap (tipo)" if gap_kind.blank?
    end
    blockers
  end

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

  # PB-020e — gap_kind é classificação de GAP: nunca em execução e sempre pela lista
  # permitida (o CHECK no banco é o backstop).
  def gap_kind_rules
    return if gap_kind.blank?

    errors.add(:base, "Tipo de gap só se aplica a blocos de gap.") unless gap?
    errors.add(:base, "Tipo de gap inválido.") unless GAP_KINDS.include?(gap_kind)
  end

  # PB-020e — confirmar = validar para o subtotal de tempo. Regras do contrato:
  # duração > 0; execution exige cliente+tarefa (validar tempo); gap exige gap_kind
  # (classificação manual). Draft/discarded seguem livres (rascunho — PB-020d).
  def confirmation_rules
    return unless confirmed?

    errors.add(:base, "Duração deve ser maior que zero para confirmar o bloco.") unless duration_seconds.to_i.positive?

    if execution?
      errors.add(:base, "Cliente é obrigatório para validar tempo.") if client_id.blank?
      errors.add(:base, "Tarefa é obrigatória para validar tempo.") if task_id.blank?
    elsif gap_kind.blank?
      errors.add(:base, "Classifique o gap (tipo) para confirmar.")
    end
  end
end
