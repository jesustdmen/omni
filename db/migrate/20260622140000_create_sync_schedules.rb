# PB-016a — agendamento interno da sincronização (modo agendado, além do manual).
# Tabela singleton (1 linha): liga/desliga + intervalo em minutos + carimbo do
# último disparo agendado. Sem Tarefa do Windows; o disparo é feito por um job
# recorrente do SolidQueue (ScheduledSyncJob), dentro do próprio Omni.
class CreateSyncSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_schedules, id: :uuid do |t|
      t.boolean :enabled, null: false, default: false
      t.integer :interval_minutes, null: false, default: 60
      t.datetime :last_enqueued_at
      t.timestamps
    end

    # Garante no máximo 1 linha de configuração (singleton): índice único numa
    # expressão constante. Postgres aceita índice único sobre uma coluna gerada
    # virtual; aqui usamos uma constante via índice único parcial sobre (true).
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_sync_schedules_singleton ON sync_schedules ((true));
        SQL
      end
      dir.down do
        execute "DROP INDEX IF EXISTS idx_sync_schedules_singleton;"
      end
    end
  end
end
