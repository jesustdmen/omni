# PB-019b — Contratos (frente comercial; ADR-025).
# Contrato pertence a Empresa Prestadora + Cliente, com Projeto OPCIONAL (quando
# informado, especializa o contrato — tem prioridade sobre o geral do cliente no
# cálculo futuro). Nesta fatia: CRUD básico, só modalidade `hourly` com `hourly_rate`.
# Integridade de sobreposição é feita por validação Rails (sem EXCLUDE/btree_gist
# nesta fatia — risco residual de concorrência registrado no ADR-025).
class CreateContracts < ActiveRecord::Migration[8.1]
  def change
    create_table :contracts, id: :uuid do |t|
      t.references :provider_company, null: false, type: :uuid, foreign_key: { on_delete: :restrict }
      t.references :client,           null: false, type: :uuid, foreign_key: { on_delete: :restrict }
      t.references :project,          null: true,  type: :uuid, foreign_key: { on_delete: :nullify }
      t.string   :modality,    null: false, default: "hourly"
      t.decimal  :hourly_rate, precision: 12, scale: 4
      t.string   :status,      null: false, default: "draft"
      t.date     :start_date,  null: false
      t.date     :end_date # null = vigência aberta
      t.text     :notes
      t.boolean  :active,      null: false, default: true
      t.timestamps
    end

    add_index :contracts, [ :provider_company_id, :client_id ]
    add_index :contracts, :status
    add_index :contracts, :start_date

    add_check_constraint :contracts,
                         "status IN ('draft','active','suspended','ended')",
                         name: "contracts_status_check"
    add_check_constraint :contracts, "modality IN ('hourly')", name: "contracts_modality_check"
    # Coerência mínima de vigência no banco (a validação Rails dá a mensagem amigável).
    add_check_constraint :contracts,
                         "end_date IS NULL OR end_date >= start_date",
                         name: "contracts_period_check"
  end
end
