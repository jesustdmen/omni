# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_25_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "checklist_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.uuid "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_checklist_items_on_task_id"
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "address"
    t.string "cnpj"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "status", default: "active", null: false
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.text "workspace_paths", default: [], null: false, array: true
    t.index ["cnpj"], name: "index_clients_on_cnpj_unique", unique: true, where: "(cnpj IS NOT NULL)"
    t.index ["created_at"], name: "index_clients_on_created_at"
    t.index ["name"], name: "index_clients_on_name"
    t.index ["workspace_paths"], name: "index_clients_on_workspace_paths", using: :gin
  end

  create_table "configurable_statuses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "entity_type", null: false
    t.boolean "final", default: false, null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["entity_type", "key"], name: "idx_configurable_statuses_entity_key", unique: true
    t.index ["entity_type", "position"], name: "idx_configurable_statuses_entity_position"
    t.check_constraint "entity_type::text = ANY (ARRAY['task'::character varying, 'project'::character varying]::text[])", name: "configurable_statuses_entity_type_check"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "is_primary", default: false, null: false
    t.string "name", null: false
    t.string "phone"
    t.string "position"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "idx_contacts_one_primary_per_client", unique: true, where: "is_primary"
    t.index ["client_id"], name: "index_contacts_on_client_id"
    t.index ["email"], name: "index_contacts_on_email"
  end

  create_table "contracts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.decimal "hourly_rate", precision: 12, scale: 4
    t.string "modality", default: "hourly", null: false
    t.text "notes"
    t.uuid "project_id"
    t.uuid "provider_company_id", null: false
    t.date "start_date", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_contracts_on_client_id"
    t.index ["project_id"], name: "index_contracts_on_project_id"
    t.index ["provider_company_id", "client_id"], name: "index_contracts_on_provider_company_id_and_client_id"
    t.index ["provider_company_id"], name: "index_contracts_on_provider_company_id"
    t.index ["start_date"], name: "index_contracts_on_start_date"
    t.index ["status"], name: "index_contracts_on_status"
    t.check_constraint "end_date IS NULL OR end_date >= start_date", name: "contracts_period_check"
    t.check_constraint "modality::text = 'hourly'::text", name: "contracts_modality_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'active'::character varying, 'suspended'::character varying, 'ended'::character varying]::text[])", name: "contracts_status_check"
  end

  create_table "conversation_activity_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.integer "position", default: 0, null: false
    t.text "source", default: "manual", null: false
    t.text "status", default: "draft", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_id"
    t.index ["conversation_id", "position"], name: "idx_activity_drafts_conversation_position"
    t.index ["conversation_id"], name: "index_conversation_activity_drafts_on_conversation_id"
    t.index ["created_by_id"], name: "index_conversation_activity_drafts_on_created_by_id"
    t.index ["updated_by_id"], name: "index_conversation_activity_drafts_on_updated_by_id"
    t.check_constraint "source = 'manual'::text", name: "conversation_activity_drafts_source_check"
    t.check_constraint "status = ANY (ARRAY['draft'::text, 'confirmed'::text, 'discarded'::text])", name: "conversation_activity_drafts_status_check"
  end

  create_table "conversation_links", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "confidence", precision: 5, scale: 4
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "link_type", default: "primary", null: false
    t.text "origin", default: "manual", null: false
    t.uuid "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "task_id", "link_type"], name: "idx_conv_links_unique_triple", unique: true
    t.index ["conversation_id"], name: "idx_conv_links_one_primary_per_conversation", unique: true, where: "(link_type = 'primary'::text)"
    t.index ["conversation_id"], name: "index_conversation_links_on_conversation_id"
    t.index ["created_by_id"], name: "index_conversation_links_on_created_by_id"
    t.index ["task_id"], name: "index_conversation_links_on_task_id"
    t.check_constraint "confidence IS NULL OR confidence >= 0::numeric AND confidence <= 1::numeric", name: "conversation_links_confidence_check"
    t.check_constraint "link_type = ANY (ARRAY['primary'::text, 'mention'::text])", name: "conversation_links_link_type_check"
    t.check_constraint "origin = ANY (ARRAY['manual'::text, 'auto'::text, 'suggestion'::text])", name: "conversation_links_origin_check"
  end

  create_table "conversation_triages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "confirmed_client_id"
    t.uuid "confirmed_project_id"
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.text "status", default: "open", null: false
    t.bigint "triaged_by_id"
    t.datetime "updated_at", null: false
    t.index ["confirmed_client_id"], name: "index_conversation_triages_on_confirmed_client_id"
    t.index ["confirmed_project_id"], name: "index_conversation_triages_on_confirmed_project_id"
    t.index ["conversation_id"], name: "index_conversation_triages_on_conversation_id", unique: true
    t.index ["triaged_by_id"], name: "index_conversation_triages_on_triaged_by_id"
    t.check_constraint "status = ANY (ARRAY['open'::text, 'reviewed'::text, 'ignored'::text])", name: "conversation_triages_status_check"
  end

  create_table "conversation_turn_refs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_offset", null: false
    t.uuid "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "line_no", null: false
    t.text "role"
    t.text "thread_id", null: false
    t.timestamptz "ts"
    t.uuid "turn_source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "line_no"], name: "idx_turn_refs_conversation_line"
    t.index ["thread_id", "line_no"], name: "idx_turn_refs_thread_line"
    t.index ["turn_source_id", "conversation_id", "line_no"], name: "idx_turn_refs_unique_source_conv_line", unique: true
    t.index ["turn_source_id", "line_no"], name: "idx_turn_refs_unique_source_line", unique: true
    t.index ["turn_source_id"], name: "index_conversation_turn_refs_on_turn_source_id"
    t.check_constraint "byte_offset >= 0", name: "conversation_turn_refs_byte_offset_check"
    t.check_constraint "line_no > 0", name: "conversation_turn_refs_line_no_check"
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "assistant_turns", default: 0, null: false
    t.datetime "created_at", null: false
    t.jsonb "files_changed", default: [], null: false
    t.timestamptz "first_ts"
    t.timestamptz "last_ts"
    t.integer "message_count", default: 0, null: false
    t.boolean "personal", default: false, null: false
    t.text "session_id"
    t.text "source"
    t.text "thread_id", null: false
    t.text "title"
    t.integer "tool_calls", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "user_turns", default: 0, null: false
    t.text "workspace_hash"
    t.index ["last_ts"], name: "index_conversations_on_last_ts"
    t.index ["thread_id"], name: "index_conversations_on_thread_id", unique: true
    t.index ["user_id"], name: "index_conversations_on_user_id"
    t.index ["workspace_hash"], name: "index_conversations_on_workspace_hash"
    t.check_constraint "message_count >= 0 AND user_turns >= 0 AND assistant_turns >= 0 AND tool_calls >= 0", name: "conversations_counts_non_negative"
  end

  create_table "demands", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id"
    t.datetime "converted_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.text "observations"
    t.string "origin", null: false
    t.string "priority", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_demands_on_client_id"
    t.index ["created_at"], name: "index_demands_on_created_at"
    t.index ["priority"], name: "index_demands_on_priority"
    t.index ["status"], name: "index_demands_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'converted'::character varying]::text[])", name: "demands_status_check"
  end

  create_table "projects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "budget"
    t.uuid "client_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.date "end_date"
    t.string "name", null: false
    t.date "start_date"
    t.string "status", default: "planning", null: false
    t.string "status_entity", default: "project", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_projects_on_client_id"
    t.index ["created_at"], name: "index_projects_on_created_at"
    t.index ["status"], name: "index_projects_on_status"
    t.check_constraint "status_entity::text = 'project'::text", name: "projects_status_entity_check"
  end

  create_table "provider_companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.string "cnpj"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.string "trade_name"
    t.datetime "updated_at", null: false
    t.index ["cnpj"], name: "index_provider_companies_on_cnpj_unique", unique: true, where: "(cnpj IS NOT NULL)"
    t.index ["name"], name: "index_provider_companies_on_name"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sync_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "current_step"
    t.text "error_message"
    t.datetime "finished_at"
    t.integer "pipeline_exit_code"
    t.text "pipeline_summary"
    t.bigint "requested_by_id"
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.string "trigger", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.index "(((status)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[])))", name: "idx_sync_executions_one_active", unique: true, where: "((status)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[]))"
    t.index ["created_at"], name: "index_sync_executions_on_created_at"
    t.index ["status"], name: "index_sync_executions_on_status"
  end

  create_table "sync_run_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "line_number"
    t.text "raw_excerpt"
    t.text "reason"
    t.text "status"
    t.uuid "sync_run_id", null: false
    t.text "thread_id"
    t.datetime "updated_at", null: false
    t.index ["sync_run_id"], name: "index_sync_run_items_on_sync_run_id"
    t.check_constraint "status = ANY (ARRAY['error'::text, 'skipped'::text])", name: "sync_run_items_status_check"
  end

  create_table "sync_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "error_lines", default: 0, null: false
    t.timestamptz "finished_at"
    t.integer "imported", default: 0, null: false
    t.integer "lines_processed", default: 0, null: false
    t.text "schema_version"
    t.integer "skipped", default: 0, null: false
    t.text "source_file"
    t.text "source_label"
    t.timestamptz "source_mtime"
    t.timestamptz "started_at"
    t.text "status", default: "ok", null: false
    t.uuid "sync_execution_id"
    t.integer "updated", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["sync_execution_id"], name: "index_sync_runs_on_sync_execution_id"
    t.check_constraint "lines_processed >= 0 AND imported >= 0 AND updated >= 0 AND skipped >= 0 AND error_lines >= 0", name: "sync_runs_counts_non_negative"
    t.check_constraint "status = ANY (ARRAY['ok'::text, 'partial'::text, 'error'::text])", name: "sync_runs_status_check"
  end

  create_table "sync_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: false, null: false
    t.integer "interval_minutes", default: 60, null: false
    t.datetime "last_enqueued_at"
    t.datetime "updated_at", null: false
    t.index "(true)", name: "idx_sync_schedules_singleton", unique: true
  end

  create_table "tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.bigserial "code_number", null: false
    t.integer "conversation_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.uuid "demand_id"
    t.text "description"
    t.datetime "last_conversation_at"
    t.uuid "project_id"
    t.string "status", default: "todo", null: false
    t.string "status_entity", default: "task", null: false
    t.string "title", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_tasks_on_client_id"
    t.index ["code_number"], name: "index_tasks_on_code_number", unique: true
    t.index ["created_at"], name: "index_tasks_on_created_at"
    t.index ["demand_id"], name: "idx_tasks_one_per_demand", unique: true, where: "(demand_id IS NOT NULL)"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["type"], name: "index_tasks_on_type"
    t.check_constraint "status_entity::text = 'task'::text", name: "tasks_status_entity_check"
  end

  create_table "time_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "description"
    t.integer "duration", default: 0, null: false
    t.timestamptz "end_time"
    t.boolean "is_running", default: false, null: false
    t.timestamptz "start_time", null: false
    t.uuid "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_time_entries_on_conversation_id"
    t.index ["date"], name: "index_time_entries_on_date"
    t.index ["start_time"], name: "index_time_entries_on_start_time"
    t.index ["task_id"], name: "idx_time_entries_one_running_per_task", unique: true, where: "is_running"
    t.index ["task_id"], name: "index_time_entries_on_task_id"
    t.check_constraint "duration >= 0", name: "time_entries_duration_check"
  end

  create_table "turn_sources", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content_hash", null: false
    t.datetime "created_at", null: false
    t.timestamptz "indexed_at"
    t.text "schema_version", null: false
    t.bigint "size_bytes", null: false
    t.text "source_file", null: false
    t.text "source_label", null: false
    t.timestamptz "source_mtime", null: false
    t.text "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["source_file", "size_bytes", "source_mtime", "content_hash", "schema_version"], name: "idx_turn_sources_fingerprint", unique: true
    t.check_constraint "status = ANY (ARRAY['pending'::text, 'ok'::text, 'partial'::text, 'stale'::text, 'error'::text])", name: "turn_sources_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["is_active"], name: "index_users_on_is_active"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "workspace_maps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "folder"
    t.datetime "updated_at", null: false
    t.text "workspace_hash", null: false
    t.index ["workspace_hash"], name: "index_workspace_maps_on_workspace_hash", unique: true
  end

  add_foreign_key "checklist_items", "tasks", on_delete: :cascade
  add_foreign_key "contacts", "clients", on_delete: :cascade
  add_foreign_key "contracts", "clients", on_delete: :restrict
  add_foreign_key "contracts", "projects", on_delete: :nullify
  add_foreign_key "contracts", "provider_companies", on_delete: :restrict
  add_foreign_key "conversation_activity_drafts", "conversations", on_delete: :cascade
  add_foreign_key "conversation_activity_drafts", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "conversation_activity_drafts", "users", column: "updated_by_id", on_delete: :nullify
  add_foreign_key "conversation_links", "conversations", on_delete: :cascade
  add_foreign_key "conversation_links", "tasks", on_delete: :cascade
  add_foreign_key "conversation_links", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "conversation_triages", "clients", column: "confirmed_client_id", on_delete: :nullify
  add_foreign_key "conversation_triages", "conversations", on_delete: :cascade
  add_foreign_key "conversation_triages", "projects", column: "confirmed_project_id", on_delete: :nullify
  add_foreign_key "conversation_triages", "users", column: "triaged_by_id", on_delete: :nullify
  add_foreign_key "conversation_turn_refs", "conversations", on_delete: :cascade
  add_foreign_key "conversation_turn_refs", "turn_sources", on_delete: :cascade
  add_foreign_key "conversations", "users", on_delete: :nullify
  add_foreign_key "demands", "clients", on_delete: :nullify
  add_foreign_key "projects", "clients", on_delete: :cascade
  add_foreign_key "projects", "configurable_statuses", column: ["status_entity", "status"], primary_key: ["entity_type", "key"], name: "fk_projects_status", on_update: :cascade, on_delete: :restrict
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sync_run_items", "sync_runs", on_delete: :cascade
  add_foreign_key "tasks", "clients", on_delete: :cascade
  add_foreign_key "tasks", "configurable_statuses", column: ["status_entity", "status"], primary_key: ["entity_type", "key"], name: "fk_tasks_status", on_update: :cascade, on_delete: :restrict
  add_foreign_key "tasks", "demands", on_delete: :restrict
  add_foreign_key "tasks", "projects", on_delete: :nullify
  add_foreign_key "time_entries", "tasks", on_delete: :cascade
end
