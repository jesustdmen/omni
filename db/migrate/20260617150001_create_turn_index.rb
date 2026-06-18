class CreateTurnIndex < ActiveRecord::Migration[8.1]
  def change
    # Identidade da versão indexada do sessions.jsonl (fingerprint). ADR-021.
    create_table :turn_sources, id: :uuid do |t|
      t.text :source_label, null: false
      t.text :source_file, null: false
      t.bigint :size_bytes, null: false
      t.timestamptz :source_mtime, null: false
      t.text :content_hash, null: false
      t.text :schema_version, null: false
      t.timestamptz :indexed_at
      t.text :status, null: false, default: "pending"

      t.timestamps
    end

    add_check_constraint :turn_sources,
      "status IN ('pending','ok','partial','stale','error')",
      name: "turn_sources_status_check"

    # Uma linha por versão de arquivo (fingerprint completo).
    add_index :turn_sources,
      %i[source_file size_bytes source_mtime content_hash schema_version],
      unique: true, name: "idx_turn_sources_fingerprint"

    # Ponteiros para os turnos no arquivo — SEM conteúdo (sem text/tool_input). ADR-021.
    create_table :conversation_turn_refs, id: :uuid do |t|
      t.references :turn_source, null: false, type: :uuid, index: false,
                   foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, type: :uuid, index: false,
                   foreign_key: { on_delete: :cascade }
      t.text :thread_id, null: false
      t.integer :line_no, null: false
      t.bigint :byte_offset, null: false
      t.text :role        # projeção leve (ordenar/contar sem abrir o arquivo)
      t.timestamptz :ts   # projeção leve

      t.timestamps
    end

    add_check_constraint :conversation_turn_refs, "byte_offset >= 0",
      name: "conversation_turn_refs_byte_offset_check"
    add_check_constraint :conversation_turn_refs, "line_no > 0",
      name: "conversation_turn_refs_line_no_check"

    # Integridade: um ref por linha física, por versão de arquivo.
    add_index :conversation_turn_refs, %i[turn_source_id line_no], unique: true,
      name: "idx_turn_refs_unique_source_line"
    # Cobre a query do loader (source + conversa, ordenado por line_no). Unicidade
    # implícita pela anterior; mantida conforme contrato e útil como índice de cobertura.
    add_index :conversation_turn_refs, %i[turn_source_id conversation_id line_no], unique: true,
      name: "idx_turn_refs_unique_source_conv_line"
    # Listagem por conversa (independente do source corrente).
    add_index :conversation_turn_refs, %i[conversation_id line_no],
      name: "idx_turn_refs_conversation_line"
    # Lookup/rebuild por thread.
    add_index :conversation_turn_refs, %i[thread_id line_no],
      name: "idx_turn_refs_thread_line"
    # Índice do FK turn_source (a unique composta já cobre o prefixo, mantido por clareza do FK).
    add_index :conversation_turn_refs, :turn_source_id,
      name: "index_conversation_turn_refs_on_turn_source_id"
  end
end
