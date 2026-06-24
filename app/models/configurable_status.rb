# PB-018 — Status configurável de Tarefas e Projetos.
#
# Cada linha define um status de UMA entidade (`entity_type` = 'task' | 'project').
# A `key` é o que fica gravado em `tasks.status` / `projects.status` (string), com
# FK composta garantindo integridade no banco (ver migration). `name` é o rótulo
# PT-BR exibido; `color` controla a cor do badge; `position` ordena; `active`
# controla se aparece para NOVOS registros; `final` ("finalizador") afeta apenas
# filtros/exibição — NÃO dispara regra comercial/cálculo/fechamento/bloqueio.
class ConfigurableStatus < ApplicationRecord
  ENTITY_TYPES = %w[task project].freeze

  # Cor por allowlist de formato (hex #rrggbb ou #rgb) — nunca texto livre que
  # possa virar payload em style/atributo. A renderização ainda escapa o valor.
  COLOR_FORMAT = /\A#(?:\h{6}|\h{3})\z/

  # Chave segura: snake_case ASCII, começa por letra, sem espaços/símbolos.
  KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/

  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }
  validates :key, presence: true,
                  format: { with: KEY_FORMAT, message: "deve ser snake_case ASCII (ex.: em_revisao)" },
                  uniqueness: { scope: :entity_type, case_sensitive: false }
  validates :name, presence: true
  validates :color, presence: true, format: { with: COLOR_FORMAT, message: "deve ser uma cor hex (ex.: #3B82F6)" }
  validates :position, presence: true, numericality: { only_integer: true }
  validates :active, inclusion: { in: [ true, false ] }
  validates :final, inclusion: { in: [ true, false ] }

  normalizes :key, with: ->(v) { v.to_s.strip.downcase }
  normalizes :name, with: ->(v) { v.to_s.strip }
  normalizes :color, with: ->(v) { v.to_s.strip }

  scope :for_entity, ->(entity) { where(entity_type: entity) }
  scope :ordered, -> { order(:position, :key) }
  scope :active, -> { where(active: true) }

  # Status em uso pela entidade dona (impede exclusão livre — regra de negócio +
  # rede de proteção da FK ON DELETE RESTRICT no banco).
  def in_use?
    entity_model.where(status: key).exists?
  end

  def entity_model
    case entity_type
    when "task"    then Task
    when "project" then Project
    end
  end

  # --- Acesso por entidade (cacheável por request se necessário; hoje query direta) ---

  # Mapa key => name para rótulos (inclui inativos — registros antigos exibem o label).
  def self.labels_for(entity)
    for_entity(entity).pluck(:key, :name).to_h
  end

  # Mapa key => color para badges (inclui inativos).
  def self.colors_for(entity)
    for_entity(entity).pluck(:key, :color).to_h
  end

  # Todas as keys válidas da entidade (ativos + inativos) — usado na allowlist de filtro.
  def self.keys_for(entity)
    for_entity(entity).order(:position, :key).pluck(:key)
  end

  # Opções [label, key] para <select> de NOVOS/edição: só ativos, MAIS o status
  # atual do registro (mesmo inativo) para não "sumir" o valor já gravado.
  def self.select_options(entity, current_key: nil)
    rows = for_entity(entity).ordered.to_a
    visible = rows.select { |s| s.active? || s.key == current_key.to_s }
    visible.map { |s| [ s.name, s.key ] }
  end

  # Label de uma key (fallback para a própria key se não houver registro).
  def self.label_for(entity, key)
    return key.to_s if key.blank?

    labels_for(entity)[key.to_s] || key.to_s
  end
end
