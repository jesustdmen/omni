# PB-006 — garante no máximo 1 contato principal por cliente (índice único parcial).
# Aditiva: não altera/remove dados. ETAPA ZERO confirmou 0 clientes com >1 principal.
class AddOnePrimaryContactPerClientIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :contacts, :client_id, unique: true, where: "is_primary",
              name: "idx_contacts_one_primary_per_client"
  end
end
