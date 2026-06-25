# PB-020 (Triagem) — atividades de 2º nível de uma conversa, como RASCUNHO manual.
#
# Tabela dedicada (sem reusar checklist_items, que é da TAREFA, nem a decisão de
# triagem 1:1). N por conversa, ordenadas por `position`. Status interno
# draft/confirmed/discarded (rótulos PT-BR na UI). `source` interno só `manual`
# nesta fase — coluna existe para evoluir (ex.: IA) no futuro, SEM acoplar agora.
# Nada aqui cria Task/TimeEntry nem toca ConversationLink. Aditiva.
class CreateConversationActivityDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_activity_drafts, id: :uuid do |t|
      t.references :conversation, null: false, type: :uuid,
                   foreign_key: { on_delete: :cascade }

      t.text :title, null: false
      t.text :description
      t.text :status, null: false, default: "draft"
      t.integer :position, null: false, default: 0
      t.text :source, null: false, default: "manual"

      # Auditoria (users.id é bigint — Devise). Nullable: seed/console.
      t.references :created_by, type: :bigint, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :updated_by, type: :bigint, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    # Status e origem por lista permitida no banco — sem valor livre.
    add_check_constraint :conversation_activity_drafts,
                         "status IN ('draft', 'confirmed', 'discarded')",
                         name: "conversation_activity_drafts_status_check"
    add_check_constraint :conversation_activity_drafts,
                         "source IN ('manual')",
                         name: "conversation_activity_drafts_source_check"
    # Ordenação eficiente dentro da conversa.
    add_index :conversation_activity_drafts, %i[conversation_id position],
              name: "idx_activity_drafts_conversation_position"
  end
end
