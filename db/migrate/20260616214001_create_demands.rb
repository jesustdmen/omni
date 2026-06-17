class CreateDemands < ActiveRecord::Migration[8.1]
  def change
    create_table :demands, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.string :origin, null: false
      t.string :priority, null: false
      t.references :client, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.text :observations
      t.string :status, null: false, default: "pending"
      t.datetime :converted_at

      t.timestamps
    end

    add_index :demands, :status
    add_index :demands, :priority
    add_index :demands, :created_at

    add_check_constraint :demands, "status IN ('pending','converted')", name: "demands_status_check"
  end
end
