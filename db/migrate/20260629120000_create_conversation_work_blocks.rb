# PB-020d (Triagem) — rascunhos de BLOCOS DE TRABALHO (turno/dia) de uma conversa.
#
# Unidade entre a atividade macro e o TimeEntry: um turno datado (Manhã/Tarde/Noite)
# com janela de tempo SUGERIDA/editável e tipo execution|gap. Sempre RASCUNHO nesta
# fatia; NÃO cria Task/TimeEntry, NÃO toca ConversationLink. Microatividades entram como
# SNAPSHOT TEXTUAL (sem FK p/ conversation_activity_drafts). Aditiva.
class CreateConversationWorkBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_work_blocks, id: :uuid do |t|
      t.references :conversation, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      # Snapshot do cliente/projeto/tarefa (todos OPCIONAIS — rascunho não exige task).
      t.references :client, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.references :project, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.references :task, null: true, type: :uuid, foreign_key: { on_delete: :nullify }

      t.date :period_date, null: false            # dia operacional (Brasília — ADR-023)
      t.text :day_period, null: false             # turno: manha|tarde|noite
      t.timestamptz :start_time                   # evidência/sugestão (editável; nullable)
      t.timestamptz :end_time                     # evidência/sugestão (editável; nullable)
      t.integer :duration_seconds, null: false, default: 0 # EDITÁVEL pelo humano (não derivado)
      t.text :kind, null: false, default: "execution"      # execution|gap
      t.text :summary                              # resumo (snapshot das microatividades)
      t.text :notes
      t.boolean :needs_external_evidence, null: false, default: false
      t.text :external_evidence_note
      t.text :status, null: false, default: "draft"        # draft|confirmed|discarded
      t.text :source, null: false, default: "manual"       # manual|ia_local (prepara IA futura)
      t.integer :position, null: false, default: 0

      # Auditoria (users.id é bigint — Devise). Nullable: seed/console.
      t.references :created_by, type: :bigint, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :updated_by, type: :bigint, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    # Listas permitidas no banco — sem valor livre.
    add_check_constraint :conversation_work_blocks,
                         "day_period IN ('manha', 'tarde', 'noite')",
                         name: "conversation_work_blocks_day_period_check"
    add_check_constraint :conversation_work_blocks,
                         "kind IN ('execution', 'gap')",
                         name: "conversation_work_blocks_kind_check"
    add_check_constraint :conversation_work_blocks,
                         "status IN ('draft', 'confirmed', 'discarded')",
                         name: "conversation_work_blocks_status_check"
    add_check_constraint :conversation_work_blocks,
                         "source IN ('manual', 'ia_local')",
                         name: "conversation_work_blocks_source_check"
    add_check_constraint :conversation_work_blocks,
                         "duration_seconds >= 0",
                         name: "conversation_work_blocks_duration_check"

    # Ordenação eficiente dentro da conversa, por dia.
    add_index :conversation_work_blocks, %i[conversation_id period_date position],
              name: "idx_work_blocks_conversation_date_position"
  end
end
