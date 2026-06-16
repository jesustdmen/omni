class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks, id: :uuid do |t|
      t.references :client, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :project, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.text :description
      t.string :type, null: false
      t.string :status, null: false, default: "todo"
      t.integer :conversation_count, null: false, default: 0
      t.datetime :last_conversation_at

      t.timestamps
    end

    add_index :tasks, :status
    add_index :tasks, :type
    add_index :tasks, :created_at

    # Paridade com o enum task_status do RepoA (sem usar enum nativo do Postgres).
    add_check_constraint :tasks,
      "status IN ('pending','todo','in_progress','done','canceled')",
      name: "tasks_status_check"
  end
end
