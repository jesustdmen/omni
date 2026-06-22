require "test_helper"

class SyncExecutionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
  end

  test "exige autenticação" do
    sign_out @user
    assert_no_difference "SyncExecution.count" do
      post sync_executions_path
    end
    assert_redirected_to new_user_session_path
  end

  test "dispara: cria execução e enfileira o job" do
    assert_difference "SyncExecution.count", 1 do
      assert_enqueued_with(job: SyncConversationsJob) do
        post sync_executions_path
      end
    end
    exec = SyncExecution.order(:created_at).last
    assert_equal "queued", exec.status
    assert_equal "manual", exec.trigger
    assert_equal @user.id, exec.requested_by_id
    assert_redirected_to sync_runs_path
  end

  test "bloqueia nova solicitação enquanto há execução ativa" do
    SyncExecution.create!(status: "running", trigger: "manual")
    assert_no_difference "SyncExecution.count" do
      assert_no_enqueued_jobs do
        post sync_executions_path
      end
    end
    assert_redirected_to sync_runs_path
    follow_redirect!
    assert_select ".flash--alert", /andamento/i
  end

  test "índice de execução ativa garante no máximo 1 ativa no banco" do
    SyncExecution.create!(status: "running", trigger: "manual")
    # tentar criar outra ativa diretamente viola o índice único parcial
    assert_raises(ActiveRecord::RecordNotUnique) do
      SyncExecution.connection.execute(
        "INSERT INTO sync_executions (id, status, trigger, created_at, updated_at) " \
        "VALUES (gen_random_uuid(), 'queued', 'manual', now(), now())"
      )
    end
  end

  test "UI mostra botão 'Sincronizar agora' e desabilita durante execução ativa" do
    get sync_runs_path
    assert_response :success
    assert_select "form[action=?]", sync_executions_path
    assert_select "button[type=submit]", /Sincronizar agora/ # PB-016a
    assert_select "button[type=submit][disabled]", count: 0

    SyncExecution.create!(status: "running", trigger: "manual")
    get sync_runs_path
    assert_select "button[type=submit][disabled]"
  end

  test "UI: progresso por etapa e auto-refresh aparecem só durante execução ativa" do
    # sem ativa: sem barra de progresso, sem meta refresh
    get sync_runs_path
    assert_select ".sync-progress", count: 0
    assert_select "meta[http-equiv=refresh]", count: 0

    # PB-016a — progresso por `current_step` (4 etapas no fluxo completo).
    SyncExecution.create!(status: "running", trigger: "manual", started_at: Time.current, current_step: "importing")
    get sync_runs_path
    assert_select ".sync-progress"                       # barra presente
    assert_select ".sync-progress__fill"
    assert_select ".sync-progress__pct", %r{/4}          # total de etapas = 4
    assert_select "meta[http-equiv=refresh]"             # auto-refresh ligado
  end

  test "UI: progress_percent reflete a etapa corrente (PB-016a)" do
    exec = SyncExecution.create!(status: "running", trigger: "manual", started_at: Time.current)
    assert_equal 0, exec.progress_percent                # sem current_step ainda
    exec.update!(current_step: "collecting")             # etapa 1/4
    assert_equal 25, exec.reload.progress_percent
    exec.update!(current_step: "indexing")               # etapa 4/4
    assert_equal 100, exec.reload.progress_percent
    exec.update!(status: "partial", finished_at: Time.current)
    assert_equal 100, exec.progress_percent
  end

  test "UI mostra status e contadores da última execução" do
    exec = SyncExecution.create!(status: "ok", trigger: "manual",
                                 started_at: Time.current, finished_at: Time.current)
    SyncRun.create!(source_label: "summaries.jsonl", schema_version: "4", status: "ok",
                    lines_processed: 10, imported: 8, updated: 2, skipped: 0, error_lines: 0,
                    started_at: Time.current, finished_at: Time.current, sync_execution_id: exec.id)
    get sync_runs_path
    assert_response :success
    assert_select ".sync-status"
    assert_select ".sync-status__counters td", /summaries\.jsonl/
  end

  test "UI mostra mensagem de erro segura da última execução" do
    SyncExecution.create!(status: "error", trigger: "manual",
                          error_message: "Arquivos do output normalizado ausentes: sessions.jsonl",
                          started_at: Time.current, finished_at: Time.current)
    get sync_runs_path
    assert_select ".sync-status__error", /ausentes/
    assert_no_match(%r{/normalized/}, response.body)
  end

  # ---------------- PB-016a ----------------

  def with_pipeline_on
    prev = Rails.application.config.x.run_pipeline_internally
    Rails.application.config.x.run_pipeline_internally = true
    yield
  ensure
    Rails.application.config.x.run_pipeline_internally = prev
  end

  test "only_import: enfileira job e marca trigger manual_import" do
    assert_difference "SyncExecution.count", 1 do
      assert_enqueued_with(job: SyncConversationsJob) do
        post sync_executions_path(only_import: "1")
      end
    end
    exec = SyncExecution.order(:created_at).last
    assert_equal "manual_import", exec.trigger
    assert_redirected_to sync_runs_path
    # (o repasse de skip_pipeline ao serviço é coberto em run_conversations_sync_test)
  end

  test "create padrão usa trigger manual (coleta + importação)" do
    post sync_executions_path
    assert_equal "manual", SyncExecution.order(:created_at).last.trigger
  end

  test "UI com pipeline ON: rótulos de coleta + opção secundária 'Importar arquivos disponíveis'" do
    with_pipeline_on do
      get sync_runs_path
      assert_response :success
      assert_select ".page-head__sub", /[Cc]oleta/
      assert_select "form[action=?]", sync_executions_path(only_import: "1")
      assert_select "button[type=submit]", /Importar arquivos disponíveis/
    end
  end

  test "UI com pipeline OFF: sem opção secundária; texto deixa claro que só importa" do
    get sync_runs_path
    assert_response :success
    assert_select "form[action=?]", sync_executions_path(only_import: "1"), count: 0
    assert_select ".page-head__sub", /[Ii]mporta/
  end

  test "UI mostra resumo seguro do pipeline da última execução" do
    SyncExecution.create!(status: "ok", trigger: "manual", pipeline_exit_code: 0,
                          pipeline_summary: "exit=0 · 1647 conversas",
                          started_at: Time.current, finished_at: Time.current)
    get sync_runs_path
    assert_select ".sync-status__pipeline", /exit=0/
  end
end
