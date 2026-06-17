class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs, id: :uuid do |t|
      t.text :source_label
      t.text :source_file
      t.column :source_mtime, :timestamptz
      t.text :schema_version
      t.text :status, null: false, default: "ok"
      t.column :started_at, :timestamptz
      t.column :finished_at, :timestamptz
      t.integer :lines_processed, null: false, default: 0
      t.integer :imported, null: false, default: 0
      t.integer :updated, null: false, default: 0
      t.integer :skipped, null: false, default: 0
      t.integer :error_lines, null: false, default: 0

      t.timestamps
    end

    add_check_constraint :sync_runs, "status IN ('ok','partial','error')", name: "sync_runs_status_check"
    add_check_constraint :sync_runs,
      "lines_processed >= 0 AND imported >= 0 AND updated >= 0 AND skipped >= 0 AND error_lines >= 0",
      name: "sync_runs_counts_non_negative"
  end
end
