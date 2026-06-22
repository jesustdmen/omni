# PB-014 — código legível de tarefa (TSK-000006 → `code_number` bigint).
# Geração por SEQUENCE do PostgreSQL (concorrência segura no banco; nunca
# `maximum + 1`). Gaps após rollback/exclusão são aceitáveis (sequence não
# reutiliza). Reabre o ADR-016.
#
# Ordem (idempotência de schema): coluna nullable → sequence dedicada →
# backfill determinístico (created_at ASC, id ASC) → setval no maior número →
# DEFAULT nextval → NOT NULL → índice unique. Reversível.
class AddCodeNumberToTasks < ActiveRecord::Migration[8.1]
  SEQ = "tasks_code_number_seq".freeze

  def up
    add_column :tasks, :code_number, :bigint

    # Sequence dedicada, "dona" da coluna (sai junto no down/drop da coluna).
    execute <<~SQL
      CREATE SEQUENCE #{SEQ} OWNED BY tasks.code_number;
    SQL

    # Backfill determinístico: numera as tarefas existentes por created_at ASC, id ASC.
    # Sem hardcode de IDs; usa a própria sequence para garantir continuidade.
    execute <<~SQL
      WITH ordered AS (
        SELECT id, nextval('#{SEQ}') AS n
        FROM (
          SELECT id FROM tasks ORDER BY created_at ASC, id ASC
        ) s
      )
      UPDATE tasks t
      SET code_number = ordered.n
      FROM ordered
      WHERE t.id = ordered.id;
    SQL

    # A sequence já está posicionada no maior valor atribuído (nextval avançou).
    # Default passa a gerar o próximo valor automaticamente para novas tarefas.
    execute <<~SQL
      ALTER TABLE tasks ALTER COLUMN code_number SET DEFAULT nextval('#{SEQ}');
    SQL

    change_column_null :tasks, :code_number, false
    add_index :tasks, :code_number, unique: true, name: "index_tasks_on_code_number"
  end

  def down
    remove_index :tasks, name: "index_tasks_on_code_number"
    # Remover a coluna leva junto o DEFAULT e a SEQUENCE (OWNED BY).
    remove_column :tasks, :code_number
  end
end
