class Client < ApplicationRecord
  has_many :contacts, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :demands, dependent: :nullify

  before_validation :normalize_cnpj

  validates :name, presence: true
  validates :cnpj, uniqueness: true, allow_nil: true

  scope :ordered, -> { order(:name, :id) }

  # PB-006 — só dígitos (busca/cadastro de CNPJ com OU sem pontuação batem no mesmo valor).
  def self.normalize_cnpj_digits(value)
    value.to_s.gsub(/\D/, "")
  end

  # Entrada de workspace_paths via textarea (uma pasta por linha).
  def workspace_paths_text=(value)
    self.workspace_paths = value.to_s.split(/[\r\n,]+/).map(&:strip).reject(&:blank?)
  end

  def workspace_paths_text
    Array(workspace_paths).join("\n")
  end

  private

  def normalize_cnpj
    if cnpj.blank?
      self.cnpj = nil
    else
      # PB-006 — persiste só dígitos (entrada pode vir pontuada do form/lookup).
      digits = self.class.normalize_cnpj_digits(cnpj)
      self.cnpj = digits.presence
    end
  end
end
