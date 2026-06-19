class AddPartialUniqueIndexToRunningTimeEntries < ActiveRecord::Migration[8.1]
  # PB-003a — invariante dura: no máximo 1 timer aberto (is_running) por tarefa.
  # Índice único parcial; não restringe timers em tarefas diferentes (paralelismo
  # permitido por config de aplicação). À prova de corrida/duplo-clique.
  def change
    add_index :time_entries, :task_id,
              unique: true,
              where: "is_running",
              name: "idx_time_entries_one_running_per_task"
  end
end
