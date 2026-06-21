class Contact < ApplicationRecord
  belongs_to :client

  validates :name, presence: true
  validates :email, presence: true

  scope :ordered, -> { order(:name, :id) }

  # PB-006 — ao marcar este contato como principal, desmarca o principal anterior
  # do MESMO cliente, na mesma transação do save (mantém ≤1 principal/cliente; o
  # índice único parcial é a barreira final). Contatos de outros clientes não mudam.
  before_save :demote_previous_primary, if: -> { is_primary? && (new_record? || will_save_change_to_is_primary?) }

  private

  def demote_previous_primary
    Contact.where(client_id: client_id, is_primary: true)
           .where.not(id: id)
           .update_all(is_primary: false, updated_at: Time.current)
  end
end
