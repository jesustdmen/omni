# PB-019a — Empresa Prestadora (a empresa pela qual o serviço é prestado).
# Domínio SEPARADO de `clients` (cliente atendido). Base da frente comercial
# (Contratos → Cálculo → Fechamentos → Relatórios/PDF) — ver ADR-025.
# Nesta fatia: só o cadastro básico. Logo/dados fiscais ficam para PB-022/PDF.
class CreateProviderCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_companies, id: :uuid do |t|
      t.string  :name,       null: false # razão social / nome
      t.string  :trade_name             # nome fantasia
      t.string  :cnpj                    # só dígitos (normalizado no model); opcional
      t.string  :email
      t.string  :phone
      t.string  :address
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :provider_companies, :name
    # CNPJ único APENAS entre prestadoras (índice parcial: ignora NULL). Não cruza
    # unicidade com `clients` — são tabelas/domínios distintos (ADR-025).
    add_index :provider_companies, :cnpj, unique: true,
              where: "cnpj IS NOT NULL", name: "index_provider_companies_on_cnpj_unique"
  end
end
