class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations, id: :uuid do |t|
      t.text :thread_id, null: false
      t.text :session_id
      t.text :source
      t.text :title
      t.column :first_ts, :timestamptz
      t.column :last_ts, :timestamptz
      t.integer :message_count, null: false, default: 0
      t.integer :user_turns, null: false, default: 0
      t.integer :assistant_turns, null: false, default: 0
      t.integer :tool_calls, null: false, default: 0
      t.jsonb :files_changed, null: false, default: []
      t.text :workspace_hash
      # user_id/personal: preparação para conversas pessoais (ADR-013/014). Coluna
      # presente, SEM enforcement de escopo nesta fase (comportamento na F5).
      # users.id é bigint (tabela do Devise), por isso user_id é bigint (não uuid).
      t.references :user, null: true, type: :bigint, foreign_key: { on_delete: :nullify }
      t.boolean :personal, null: false, default: false

      t.timestamps
    end

    add_index :conversations, :thread_id, unique: true
    add_index :conversations, :workspace_hash
    add_index :conversations, :last_ts

    add_check_constraint :conversations,
      "message_count >= 0 AND user_turns >= 0 AND assistant_turns >= 0 AND tool_calls >= 0",
      name: "conversations_counts_non_negative"
  end
end
