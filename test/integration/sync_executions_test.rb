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

  test "UI mostra botão 'Atualizar conversas no Omni' e desabilita durante execução ativa" do
    get sync_runs_path
    assert_response :success
    assert_select "form[action=?]", sync_executions_path
    assert_select "button[type=submit]", /Atualizar conversas no Omni/
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

    exec = SyncExecution.create!(status: "running", trigger: "manual", started_at: Time.current)
    SyncRun.create!(source_label: "summaries.jsonl", schema_version: "4", status: "ok",
                    started_at: Time.current, finished_at: Time.current, sync_execution_id: exec.id)
    get sync_runs_path
    assert_select ".sync-progress"                       # barra presente
    assert_select ".sync-progress__fill"
    assert_select ".sync-progress__pct", /1\/2/          # 1 de 2 etapas concluídas
    assert_select "meta[http-equiv=refresh]"             # auto-refresh ligado
  end

  test "UI: progress_percent reflete etapas concluídas" do
    exec = SyncExecution.create!(status: "running", trigger: "manual", started_at: Time.current)
    assert_equal 0, exec.progress_percent
    SyncRun.create!(source_label: "summaries.jsonl", schema_version: "4", status: "ok",
                    started_at: Time.current, finished_at: Time.current, sync_execution_id: exec.id)
    assert_equal 50, exec.reload.progress_percent
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
end
