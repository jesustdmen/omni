class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.references :client, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description
      t.date :start_date
      t.date :end_date
      t.string :status, null: false, default: "planning"
      t.string :budget

      t.timestamps
    end

    add_index :projects, :status
    add_index :projects, :created_at
  end
end
