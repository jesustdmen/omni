require "test_helper"

class SyncRunsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @run = SyncRun.create!(source_label: "summaries.jsonl", schema_version: "4", status: "partial",
                           lines_processed: 2399, imported: 1635, updated: 0, skipped: 1, error_lines: 0,
                           started_at: Time.current, finished_at: Time.current)
    @run.items.create!(line_number: 10, status: "skipped", reason: "sem thread_id")
  end

  test "exige autenticação" do
    sign_out @user
    get sync_runs_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza execuções" do
    get sync_runs_path
    assert_response :success
    assert_select "h1", "Sync runs"
    assert_select "td", /summaries\.jsonl/
  end

  test "show renderiza contadores e itens" do
    get sync_run_path(@run)
    assert_response :success
    assert_select "dd", /2399/
    assert_select "td", /sem thread_id/
  end

  test "é somente leitura: sem rotas de escrita" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:new_sync_run_path)
    assert_not helpers.respond_to?(:edit_sync_run_path)
  end
end
