class CreateSyncRunItems < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_run_items, id: :uuid do |t|
      t.references :sync_run, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.integer :line_number
      t.text :status
      t.text :reason
      t.text :thread_id
      t.text :raw_excerpt

      t.timestamps
    end

    add_check_constraint :sync_run_items, "status IN ('error','skipped')", name: "sync_run_items_status_check"
  end
end
