# PB-019a — Empresa Prestadora (por qual empresa eu presto o serviço).
# Domínio SEPARADO de Client. Base da frente comercial (ADR-025). Nesta fatia:
# só cadastro básico; logo/dados fiscais e vínculo User↔Prestadora ficam fora de escopo.
class ProviderCompany < ApplicationRecord
  # PB-019b — contratos da prestadora. FK ON DELETE RESTRICT no banco (impede excluir
  # prestadora com contratos); `restrict_with_error` dá a mensagem amigável no app.
  has_many :contracts, dependent: :restrict_with_error

  before_validation :normalize_cnpj

  validates :name, presence: true
  # CNPJ único APENAS entre prestadoras (não cruza com clients); opcional.
  validates :cnpj, uniqueness: true, allow_nil: true
  validates :active, inclusion: { in: [ true, false ] }

  scope :ordered, -> { order(:name, :id) }
  scope :active, -> { where(active: true) }

  # Só dígitos (mesma regra do Client — busca/cadastro com ou sem pontuação).
  def self.normalize_cnpj_digits(value)
    value.to_s.gsub(/\D/, "")
  end

  private

  def normalize_cnpj
    if cnpj.blank?
      self.cnpj = nil
    else
      # Persiste só dígitos; CNPJ que fica vazio após limpeza vira nil.
      self.cnpj = self.class.normalize_cnpj_digits(cnpj).presence
    end
  end
end
