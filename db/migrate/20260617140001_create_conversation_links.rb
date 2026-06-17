class CreateConversationLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_links, id: :uuid do |t|
      t.references :conversation, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :task, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :link_type, null: false, default: "primary"
      t.text :origin, null: false, default: "manual"
      t.decimal :confidence, precision: 5, scale: 4
      # created_by_id é bigint (segue users.id, do Devise). Auditoria (LK-08).
      t.references :created_by, null: true, type: :bigint,
                   foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    add_check_constraint :conversation_links, "link_type IN ('primary','mention')",
      name: "conversation_links_link_type_check"
    add_check_constraint :conversation_links, "origin IN ('manual','auto','suggestion')",
      name: "conversation_links_origin_check"
    add_check_constraint :conversation_links, "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)",
      name: "conversation_links_confidence_check"

    # ≤ 1 vínculo primário por conversa (LK-02).
    add_index :conversation_links, :conversation_id, unique: true, where: "link_type = 'primary'",
      name: "idx_conv_links_one_primary_per_conversation"
    # evita duplicata exata do mesmo tipo entre a mesma conversa e tarefa.
    add_index :conversation_links, %i[conversation_id task_id link_type], unique: true,
      name: "idx_conv_links_unique_triple"
  end
end
