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
    assert_select "h1", "Sincronização de conversas"
    assert_select "td", /summaries\.jsonl/
  end

  test "show renderiza contadores e itens" do
    get sync_run_path(@run)
    assert_response :success
    assert_select "dd", /2399/
    assert_select "td", /sem thread_id/
  end

  test "show oculta o caminho bruto do source_file (só o nome do arquivo)" do
    run = SyncRun.create!(source_label: "sessions.jsonl",
                          source_file: "/home/jesus/output/normalized/sessions.jsonl",
                          schema_version: "4", status: "ok",
                          started_at: Time.current, finished_at: Time.current)
    get sync_run_path(run)
    assert_response :success
    assert_select "dd", /sessions\.jsonl/            # label seguro (basename) presente
    assert_no_match(%r{/home/}, response.body)        # path bruto não vaza
    assert_no_match(%r{/normalized/}, response.body)
    assert_not_includes response.body, "jesus"        # PII de path não vaza
  end

  test "é somente leitura: sem rotas de escrita" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:new_sync_run_path)
    assert_not helpers.respond_to?(:edit_sync_run_path)
  end
end
