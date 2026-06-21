# PB-004b — checklist persistente da tarefa. Aditiva: nova tabela, não altera/remove
# dados existentes. FK para tasks com ON DELETE CASCADE (itens somem com a tarefa).
class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items, id: :uuid do |t|
      t.references :task, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.text :content, null: false
      t.boolean :completed, null: false, default: false
      t.timestamps
    end
  end
end
