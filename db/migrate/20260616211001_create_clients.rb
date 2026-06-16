class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients, id: :uuid do |t|
      t.string :name, null: false
      t.string :trade_name
      t.string :cnpj
      t.string :phone
      t.string :address
      t.string :status, null: false, default: "active"
      t.text :workspace_paths, array: true, null: false, default: []

      t.timestamps
    end

    # CNPJ é opcional (ADR-017); unicidade só quando preenchido.
    add_index :clients, :cnpj, unique: true, where: "cnpj IS NOT NULL", name: "index_clients_on_cnpj_unique"
    add_index :clients, :name
    add_index :clients, :created_at
    # Match determinístico de workspace por prefixo (scorer, fases futuras).
    add_index :clients, :workspace_paths, using: :gin
  end
end
