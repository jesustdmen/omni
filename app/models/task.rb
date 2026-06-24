class Task < ApplicationRecord
  # Mantém a coluna `type` por paridade com o RepoA, sem ativar STI.
  self.inheritance_column = :_type_disabled

  # Lista fechada confirmada no validator do RepoA (server/src/validators/tasks.ts).
  TYPES = %w[support question implementation development commercial].freeze
  # PB-018 (termos PT-BR) — rótulos de exibição do tipo (lista fixa, não configurável).
  TYPE_LABELS = {
    "support" => "Suporte", "question" => "Dúvida", "implementation" => "Implementação",
    "development" => "Desenvolvimento", "commercial" => "Comercial"
  }.freeze

  def self.type_label(value)
    TYPE_LABELS.fetch(value.to_s, value.to_s)
  end

  def type_label
    self.class.type_label(type)
  end

  belongs_to :client
  belongs_to :project, optional: true
  # PB-004c — demanda que ORIGINOU esta tarefa (opcional; 1:1 garantido por índice
  # único parcial + validação). FK ON DELETE RESTRICT no banco.
  belongs_to :origin_demand, class_name: "Demand", foreign_key: :demand_id, optional: true
  has_many :time_entries, dependent: :destroy
  # PB-004b — checklist persistente. delete_all: itens sem callbacks; a FK no banco
  # (ON DELETE CASCADE) também garante a remoção ao excluir a tarefa.
  has_many :checklist_items, dependent: :delete_all
  # delete_all: a tarefa some → não há por que recomputar counters dela (sem callbacks).
  has_many :conversation_links, dependent: :delete_all
  has_many :conversations, through: :conversation_links

  # PB-018 — status configurável (tabela `configurable_statuses`, entity_type='task').
  # A coluna `status` (string) guarda a KEY; rótulo/cor/opções vêm da tabela.
  # `status_entity` é constante ('task') e travada por CHECK + readonly — viabiliza
  # a FK composta (status_entity, status) -> configurable_statuses(entity_type, key).
  STATUS_ENTITY = "task".freeze
  attr_readonly :status_entity
  attribute :status, :string, default: "todo" # espelha o default do banco

  # PB-014 — código legível (`TSK-000001`). `code_number` é gerado pela sequence do
  # banco (DEFAULT nextval); somente leitura no app (nunca atribuído pela aplicação).
  attr_readonly :code_number

  validates :title, presence: true
  validates :type, presence: true, inclusion: { in: TYPES }
  validates :status, presence: true
  validate :status_is_assignable

  # Substitui o antigo `Task.statuses.keys` / `Task.statuses.key?` (enum removido na
  # PB-018). Fonte agora é a tabela de status configuráveis.
  def self.status_keys
    ConfigurableStatus.keys_for(STATUS_ENTITY)
  end

  def self.status_key?(value)
    value.present? && status_keys.include?(value.to_s)
  end

  def status_label
    ConfigurableStatus.label_for(STATUS_ENTITY, status)
  end
  # PB-004c — no máximo 1 tarefa por demanda (espelha o índice único parcial).
  validates :demand_id, uniqueness: true, allow_nil: true
  validate :project_belongs_to_same_client

  # PB-014 — código operacional legível e estável (não substitui a PK/UUID).
  # `TSK-` + 6 dígitos zero-padded (cresce além de 6 dígitos se necessário).
  def code
    return if code_number.blank?

    format("TSK-%06d", code_number)
  end

  # PB-014 — extrai o `code_number` de um termo de busca. Reconhece (case-insensitive,
  # com espaços ao redor): "TSK-000001", "tsk-1", "TSK000001" e número puro "1".
  # Retorna o Integer ou nil quando o termo não é um código/número de tarefa.
  CODE_TERM = /\A\s*(?:tsk[-\s]?)?0*(\d{1,18})\s*\z/i
  def self.code_number_from(term)
    m = CODE_TERM.match(term.to_s)
    m && m[1].to_i
  end

  # Soma read-only das durações dos apontamentos desta tarefa (F2.5).
  def total_duration
    time_entries.sum(:duration)
  end

  # F4: recomputa os counters de conversa a partir dos vínculos PRIMARY de
  # conversas NÃO-personal (ADR-013). Idempotente; usa update_columns (sem callbacks/validações).
  def recompute_conversation_counters!
    primary = conversation_links.where(link_type: "primary")
                                .joins(:conversation).where(conversations: { personal: false })
    update_columns(
      conversation_count: primary.count,
      last_conversation_at: primary.maximum("conversations.last_ts")
    )
  end

  private

  # PB-018 — o status precisa existir na tabela para 'task'. Para NOVOS valores
  # (registro novo ou troca de status), exige que o status esteja ATIVO. Um valor
  # já persistido e inalterado é aceito mesmo se ficou inativo (não quebra registros
  # antigos). A FK no banco é a rede de proteção final.
  def status_is_assignable
    return if status.blank? # 'presence' já trata vazio

    row = ConfigurableStatus.for_entity(STATUS_ENTITY).find_by(key: status)
    if row.nil?
      errors.add(:status, "não é um status válido de tarefa")
    elsif !row.active? && status_changed?
      errors.add(:status, "está inativo e não pode ser atribuído")
    end
  end

  def project_belongs_to_same_client
    return if project.blank? || client.blank?

    errors.add(:project, "deve pertencer ao mesmo cliente da tarefa") if project.client_id != client_id
  end
end
