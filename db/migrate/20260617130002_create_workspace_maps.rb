class CreateWorkspaceMaps < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_maps, id: :uuid do |t|
      t.text :workspace_hash, null: false
      # folder NULL ⇒ workspace órfão (visto em conversas, sem mapeamento conhecido).
      t.text :folder

      t.timestamps
    end

    add_index :workspace_maps, :workspace_hash, unique: true
  end
end
