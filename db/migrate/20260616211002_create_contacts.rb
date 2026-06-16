class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts, id: :uuid do |t|
      t.references :client, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :position
      t.boolean :is_primary, null: false, default: false

      t.timestamps
    end

    add_index :contacts, :email
  end
end
