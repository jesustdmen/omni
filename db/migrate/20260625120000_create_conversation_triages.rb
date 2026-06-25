# PB-020 (Triagem persistida mínima) — tabela DEDICADA da decisão humana de triagem.
# 1:1 com conversation (criada on-demand quando há decisão). NÃO toca `conversations`
# (privacidade segue em `conversations.personal`; `linked` segue derivado de
# ConversationLink). `status` = fluxo de revisão (open/reviewed/ignored); cliente/projeto
# confirmado são CAMPOS PRÓPRIOS (não status). Aditiva: não altera tabelas existentes.
class CreateConversationTriages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_triages, id: :uuid do |t|
      t.references :conversation, null: false, type: :uuid,
                   foreign_key: { on_delete: :cascade }, index: { unique: true }

      t.text :status, null: false, default: "open"

      # Confirmação humana de vínculo comercial/operacional (decisão ≠ status).
      t.references :confirmed_client, type: :uuid,
                   foreign_key: { to_table: :clients, on_delete: :nullify }
      t.references :confirmed_project, type: :uuid,
                   foreign_key: { to_table: :projects, on_delete: :nullify }

      t.text :note

      # Auditoria: quem decidiu (users.id é bigint — Devise). Nullable: seed/console.
      t.references :triaged_by, type: :bigint,
                   foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    # Status pela lista permitida no banco — sem valor livre.
    add_check_constraint :conversation_triages,
                         "status IN ('open', 'reviewed', 'ignored')",
                         name: "conversation_triages_status_check"
  end
end
