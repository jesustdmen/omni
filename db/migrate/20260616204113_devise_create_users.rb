# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Identificação adicional (Fase 1 — paridade com RepoA)
      t.string  :username,  null: false, default: ""
      t.string  :role,      null: false, default: "user"
      t.boolean :is_active, null: false, default: true

      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :username,             unique: true
    add_index :users, :role
    add_index :users, :is_active
    add_index :users, :reset_password_token, unique: true
  end
end
