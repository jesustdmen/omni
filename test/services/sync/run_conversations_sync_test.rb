require "test_helper"
require "fileutils"
require "tmpdir"

module Sync
  class RunConversationsSyncTest < ActiveSupport::TestCase
    CORPUS = Rails.root.join("test/fixtures/normalized_corpus")

    setup do
      # Diretório FIXO simulado: copia o corpus pequeno para um tmp e aponta
      # config.x.normalized_dir para ele (nunca o arquivo real de 240 MB).
      @dir = Dir.mktmpdir("normalized")
      %w[summaries.jsonl sessions.jsonl session_titles.json workspace_maps.json].each do |f|
        FileUtils.cp(CORPUS.join(f), File.join(@dir, f))
      end
      @prev_dir = Rails.application.config.x.normalized_dir
      Rails.application.config.x.normalized_dir = @dir
    end

    teardown do
      Rails.application.config.x.normalized_dir = @prev_dir
      FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
    end

    def run_sync(trigger: "manual")
      exec = SyncExecution.create!(status: "queued", trigger: trigger)
      [ Sync::RunConversationsSync.call(execution: exec), exec ]
    end

    test "executa Import e BuildRefs na ordem e conclui (partial: corpus tem 1 linha malformada)" do
      result, exec = run_sync
      exec.reload

      assert result.success?, "esperava sucesso, erro=#{result.error}"
      assert_equal "partial", exec.status # import do corpus é partial (1 linha malformada)
      assert_equal 2, Conversation.count
      assert ConversationTurnRef.count.positive?, "índice de turnos deve ser construído"
      # ambas as etapas vinculadas à execução-mãe
      labels = exec.sync_runs.pluck(:source_label).sort
      assert_includes labels, "summaries.jsonl"
      assert_includes labels, "sessions.jsonl"
    end

    test "lê apenas do diretório fixo: nunca recebe path/comando do usuário" do
      # RunConversationsSync.call aceita só execution + injeção de runner/skip (PB-016a);
      # NUNCA path, dir ou comando — esses vêm de config/ENV (allowlist).
      names = Sync::RunConversationsSync.method(:call).parameters.map(&:last)
      assert_equal %i[execution pipeline_runner skip_pipeline].sort, names.sort
      assert_empty(names & %i[path dir command script python args])
    end

    test "erro quando arquivos do normalized estão ausentes; índice anterior preservado" do
      # primeiro sync ok
      run_sync
      refs_before = ConversationTurnRef.count
      assert refs_before.positive?

      # remove os arquivos e tenta de novo
      FileUtils.rm_f(File.join(@dir, "summaries.jsonl"))
      FileUtils.rm_f(File.join(@dir, "sessions.jsonl"))
      result, exec = run_sync
      exec.reload

      assert_not result.success?
      assert_equal "error", exec.status
      assert exec.error_message.present?
      assert_equal refs_before, ConversationTurnRef.count, "índice anterior deve ser preservado em falha"
    end

    test "lock impede execução concorrente: try-lock falhando recusa sem processar" do
      busy = SyncExecution.create!(status: "queued", trigger: "manual")
      # Simula o advisory lock JÁ detido por outro backend: o try-lock retorna false.
      # (Na mesma conexão de teste o lock seria reentrante, então forçamos o retorno.)
      conn = ActiveRecord::Base.connection
      original = conn.method(:select_value)
      conn.define_singleton_method(:select_value) do |*args, **kw|
        sql = args.first.to_s
        next false if sql.include?("pg_try_advisory_lock")

        original.call(*args, **kw)
      end
      begin
        result = Sync::RunConversationsSync.call(execution: busy)
        assert_not result.success?
        assert_match(/andamento/i, result.error)
        # não tocou no estado: execução permanece queued (não virou running/ok)
        assert_equal "queued", busy.reload.status
      ensure
        conn.singleton_class.send(:remove_method, :select_value)
      end
    end

    test "advisory lock real é adquirido e liberado (re-sync subsequente funciona)" do
      r1, = run_sync
      assert r1.success?
      # se o lock não tivesse sido liberado, esta 2ª chamada recusaria:
      r2, exec2 = run_sync
      assert r2.success?, "lock deve ter sido liberado para a próxima execução"
      assert_includes %w[ok partial], exec2.reload.status
    end

    test "detecta arquivo reescrito durante a leitura (fingerprint antes/depois)" do
      # Faz o sessions.jsonl mudar DEPOIS do import, antes da verificação final,
      # interceptando ImportSummaries para alterar o arquivo no meio do fluxo.
      sessions = File.join(@dir, "sessions.jsonl")
      original = Sync::ImportSummaries.method(:call)
      Sync::ImportSummaries.define_singleton_method(:call) do |**kwargs|
        run = original.call(**kwargs)
        File.open(sessions, "ab") { |f| f.write("\n{\"thread_id\":\"x\",\"role\":\"user\"}\n") } # reescreve
        run
      end
      begin
        result, exec = run_sync
        exec.reload
        assert_not result.success?
        assert_equal "error", exec.status
        assert_match(/reescrito/i, exec.error_message)
      ensure
        Sync::ImportSummaries.singleton_class.send(:remove_method, :call)
        Sync::ImportSummaries.define_singleton_method(:call, original)
      end
    end

    test "preserva conversation_links e tarefas por thread_id (re-sync não destrói vínculos)" do
      run_sync # cria as conversas
      conv = Conversation.find_by(thread_id: "11111111-1111-4111-8111-111111111111")
      client = Client.create!(name: "ACME")
      task = client.tasks.create!(title: "T", type: "support")
      link = ConversationLink.create!(conversation: conv, task: task, link_type: "primary", origin: "manual")

      run_sync # segundo sync (upsert, nunca deleta)

      assert Conversation.exists?(conv.id), "conversa preservada"
      assert ConversationLink.exists?(link.id), "vínculo preservado"
      assert Task.exists?(task.id), "tarefa preservada"
    end

    test "mensagem de erro não vaza paths absolutos" do
      FileUtils.rm_f(File.join(@dir, "summaries.jsonl"))
      FileUtils.rm_f(File.join(@dir, "sessions.jsonl"))
      _result, exec = run_sync
      assert_no_match(%r{/tmp/}, exec.reload.error_message.to_s)
    end

    # ------- PB-016a: etapa do pipeline (runner FALSO; nunca o pipeline real) -------

    # Runner falso configurável: registra que foi chamado e devolve um Result.
    class FakeRunner
      attr_reader :called
      def initialize(ok:, exit_code: 0, timed_out: false, agent_offline: false, summary: "exit=0")
        @ok = ok; @exit_code = exit_code; @timed_out = timed_out
        @agent_offline = agent_offline; @summary = summary; @called = 0
      end

      def call
        @called += 1
        Sync::PipelineRunner::Result.new(ok: @ok, exit_code: @exit_code, timed_out: @timed_out,
                                         agent_offline: @agent_offline, summary: @summary)
      end
    end

    def with_pipeline_on
      prev = Rails.application.config.x.run_pipeline_internally
      Rails.application.config.x.run_pipeline_internally = true
      yield
    ensure
      Rails.application.config.x.run_pipeline_internally = prev
    end

    test "pipeline ON + sucesso: roda pipeline ANTES do import e conclui" do
      with_pipeline_on do
        runner = FakeRunner.new(ok: true, exit_code: 0, summary: "exit=0 · ok")
        exec = SyncExecution.create!(status: "queued", trigger: "manual")
        result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner)
        exec.reload
        assert result.success?, "erro=#{result.error}"
        assert_equal 1, runner.called, "pipeline deve ter sido executado"
        assert_equal 0, exec.pipeline_exit_code
        assert Conversation.count.positive?, "importação deve ter ocorrido após o pipeline"
        assert_equal "completed", exec.current_step
      end
    end

    test "pipeline ON + exit code de erro: NÃO importa, marca error, índice preservado" do
      with_pipeline_on do
        # primeiro um sync ok (sem pipeline) p/ ter um índice anterior
        run_sync
        refs_before = ConversationTurnRef.count
        convs_before = Conversation.count

        runner = FakeRunner.new(ok: false, exit_code: 3, summary: "exit=3 · boom")
        exec = SyncExecution.create!(status: "queued", trigger: "manual")
        result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner)
        exec.reload

        assert_not result.success?
        assert_equal "error", exec.status
        assert_equal 3, exec.pipeline_exit_code
        assert_match(/pipeline/i, exec.error_message)
        assert_equal refs_before, ConversationTurnRef.count, "índice preservado em falha do pipeline"
        assert_equal convs_before, Conversation.count, "nada importado quando o pipeline falha"
      end
    end

    test "pipeline ON + timeout: NÃO importa, mensagem de timeout" do
      with_pipeline_on do
        runner = FakeRunner.new(ok: false, exit_code: nil, timed_out: true, summary: "timeout")
        exec = SyncExecution.create!(status: "queued", trigger: "manual")
        result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner)
        exec.reload
        assert_not result.success?
        assert_equal "error", exec.status
        assert_match(/tempo limite/i, exec.error_message)
        assert_equal 0, Conversation.count, "nada importado em timeout do pipeline"
      end
    end

    test "pipeline OFF (default): não chama runner, só importa /normalized" do
      runner = FakeRunner.new(ok: true)
      exec = SyncExecution.create!(status: "queued", trigger: "manual")
      result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner)
      assert result.success?
      assert_equal 0, runner.called, "com pipeline OFF, o runner não deve ser chamado"
    end

    test "skip_pipeline força pular a coleta mesmo com pipeline ON" do
      with_pipeline_on do
        runner = FakeRunner.new(ok: true)
        exec = SyncExecution.create!(status: "queued", trigger: "manual_import")
        result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner, skip_pipeline: true)
        assert result.success?
        assert_equal 0, runner.called, "skip_pipeline deve pular o pipeline"
        assert Conversation.count.positive?, "importação ainda ocorre"
      end
    end

    test "pipeline ON + AGENTE OFFLINE: degrada — pula coleta e IMPORTA com aviso" do
      with_pipeline_on do
        runner = FakeRunner.new(ok: false, agent_offline: true, summary: "Agente de coleta offline.")
        exec = SyncExecution.create!(status: "queued", trigger: "manual")
        result = Sync::RunConversationsSync.call(execution: exec, pipeline_runner: runner)
        exec.reload
        assert result.success?, "agente offline NÃO deve falhar a sincronização"
        assert_includes %w[ok partial], exec.status
        assert Conversation.count.positive?, "importa o output disponível mesmo com agente offline"
        assert_match(/Coleta pulada/i, exec.pipeline_summary)
      end
    end
  end
end
