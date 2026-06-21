# PB-004c — vínculo opcional 1:1 demanda→tarefa de origem. Aditiva: coluna nullable,
# não altera/remove dados existentes. FK ON DELETE RESTRICT (não exclui demanda com
# tarefa viva) + índice ÚNICO PARCIAL (no máx. 1 tarefa por demanda).
class AddDemandToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :demand_id, :uuid, null: true
    add_foreign_key :tasks, :demands, column: :demand_id, on_delete: :restrict
    add_index :tasks, :demand_id, unique: true, where: "demand_id IS NOT NULL",
              name: "idx_tasks_one_per_demand"
  end
end
