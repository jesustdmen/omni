class Client < ApplicationRecord
  has_many :contacts, dependent: :destroy

  before_validation :normalize_cnpj

  validates :name, presence: true
  validates :cnpj, uniqueness: true, allow_nil: true

  # Entrada de workspace_paths via textarea (uma pasta por linha).
  def workspace_paths_text=(value)
    self.workspace_paths = value.to_s.split(/[\r\n,]+/).map(&:strip).reject(&:blank?)
  end

  def workspace_paths_text
    Array(workspace_paths).join("\n")
  end

  private

  def normalize_cnpj
    self.cnpj = nil if cnpj.blank?
  end
end
