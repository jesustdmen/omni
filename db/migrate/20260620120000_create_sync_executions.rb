# PB-015 — execução operacional agregada de sincronização (orquestra os SyncRun
# por etapa: ImportSummaries + BuildConversationTurnRefs). Aditiva: não altera nem
# remove dados existentes; `sync_runs.sync_execution_id` é nullable (runs antigos
# e os disparados por rake permanecem sem execução-mãe).
class CreateSyncExecutions < ActiveRecord::Migration[8.1]
  def up
    create_table :sync_executions, id: :uuid do |t|
      t.string :status, null: false, default: "queued"
      t.string :trigger, null: false, default: "manual"
      t.bigint :requested_by_id
      t.datetime :started_at
      t.datetime :finished_at
      t.text :error_message
      t.timestamps
    end

    add_index :sync_executions, :status
    add_index :sync_executions, :created_at
    # Garante no máximo 1 execução ATIVA no total (queued OU running): índice único
    # sobre uma expressão constante (TRUE) restrito às ativas → só 1 linha TRUE cabe.
    # É a salvaguarda declarativa; a serialização real vem do advisory lock no serviço.
    execute <<~SQL.squish
      CREATE UNIQUE INDEX idx_sync_executions_one_active
      ON sync_executions ((status IN ('queued','running')))
      WHERE status IN ('queued','running')
    SQL

    add_reference :sync_runs, :sync_execution, type: :uuid, null: true, index: true
  end

  def down
    remove_reference :sync_runs, :sync_execution
    drop_table :sync_executions
  end
end
