class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries, id: :uuid do |t|
      t.references :task, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :description
      t.column :start_time, :timestamptz, null: false
      t.column :end_time, :timestamptz
      t.integer :duration, null: false, default: 0
      t.date :date, null: false
      t.boolean :is_running, null: false, default: false
      # conversation_id: preparação para fase futura (F3/F4). Coluna nullable,
      # SEM FK e SEM lógica nesta fase (paridade com a abordagem de counters em tasks).
      t.uuid :conversation_id

      t.timestamps
    end

    # t.references já cria o índice de task_id.
    add_index :time_entries, :date
    add_index :time_entries, :start_time
    add_index :time_entries, :conversation_id

    add_check_constraint :time_entries, "duration >= 0", name: "time_entries_duration_check"
  end
end
