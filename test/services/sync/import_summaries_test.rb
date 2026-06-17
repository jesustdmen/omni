require "test_helper"
require "tempfile"

module Sync
  class ImportSummariesTest < ActiveSupport::TestCase
    CORPUS = Rails.root.join("test/fixtures/normalized_corpus")
    THREAD_A = "11111111-1111-4111-8111-111111111111".freeze
    THREAD_B = "a1b2c3d4e5f60718293a4b5c6d7e8f9000112233".freeze
    WS_KNOWN = "wsknown000000000000000000000000a1".freeze
    WS_ORPHAN = "wsorphan00000000000000000000000b9".freeze

    def import
      Sync::ImportSummaries.call(
        summaries_path: CORPUS.join("summaries.jsonl"),
        titles_path: CORPUS.join("session_titles.json"),
        workspace_maps_path: CORPUS.join("workspace_maps.json")
      )
    end

    # Importa linhas sintéticas (sem tocar no corpus): grava um summaries.jsonl temporário.
    def import_lines(rows)
      Tempfile.create([ "summ", ".jsonl" ]) do |file|
        rows.each { |row| file.puts(JSON.generate(row)) }
        file.flush
        return Sync::ImportSummaries.call(summaries_path: file.path)
      end
    end

    test "importa o corpus: 2 conversas e run partial com contadores" do
      run = import

      assert_equal 2, Conversation.count
      assert_equal "partial", run.status
      assert_equal "4", run.schema_version
      assert_equal 4, run.lines_processed
      assert_equal 2, run.imported
      assert_equal 0, run.updated
      assert_equal 0, run.skipped
      assert_equal 1, run.error_lines
    end

    test "linha malformada gera um único sync_run_item de erro" do
      run = import

      assert_equal 1, run.items.count
      item = run.items.first
      assert_equal "error", item.status
      assert_equal 4, item.line_number
    end

    test "merge determinístico do thread_id duplicado (A)" do
      import
      a = Conversation.find_by!(thread_id: THREAD_A)

      assert_equal Time.utc(2026, 1, 10, 8, 55, 0).to_i, a.first_ts.to_i, "first_ts = menor não-nulo"
      assert_equal Time.utc(2026, 1, 10, 10, 0, 0).to_i, a.last_ts.to_i, "last_ts = maior não-nulo"
      assert_equal 9, a.message_count
      assert_equal 4, a.user_turns
      assert_equal 5, a.assistant_turns
      assert_equal 3, a.tool_calls
      assert_equal [ "a.rb", "b.rb" ], a.files_changed, "união distinta e ordenada"
      assert_equal "claude_code_session", a.source, "source da linha de maior last_ts"
      assert_equal WS_KNOWN, a.workspace_hash, "workspace da linha de maior last_ts"
    end

    test "título canônico de session_titles.json sobrescreve o título de linha (A)" do
      import
      assert_equal "Título canônico de A (via session_titles)",
                   Conversation.find_by!(thread_id: THREAD_A).title
    end

    test "fallback de título quando não há entrada em session_titles.json (B)" do
      import
      assert_equal "Título da linha B (fallback)",
                   Conversation.find_by!(thread_id: THREAD_B).title
    end

    test "workspace conhecido é resolvido e órfão fica com folder nil" do
      import

      assert_equal "C:\\Sandbox\\proj-known", WorkspaceMap.find_by!(workspace_hash: WS_KNOWN).folder
      assert_nil WorkspaceMap.find_by!(workspace_hash: WS_ORPHAN).folder
      assert_includes WorkspaceMap.orphan.pluck(:workspace_hash), WS_ORPHAN
      assert_not_includes WorkspaceMap.orphan.pluck(:workspace_hash), WS_KNOWN
    end

    test "idempotência: rodar duas vezes não duplica e estabiliza valores" do
      import
      first = Conversation.find_by!(thread_id: THREAD_A).slice(
        :first_ts, :last_ts, :message_count, :user_turns, :assistant_turns,
        :tool_calls, :files_changed, :source, :workspace_hash, :title
      )

      run2 = import

      assert_equal 2, Conversation.count, "não duplica conversas"
      assert_equal 0, run2.imported, "segunda execução não importa novas"
      assert_equal 2, run2.updated, "segunda execução reprocessa as existentes"

      second = Conversation.find_by!(thread_id: THREAD_A).slice(
        :first_ts, :last_ts, :message_count, :user_turns, :assistant_turns,
        :tool_calls, :files_changed, :source, :workspace_hash, :title
      )
      assert_equal first, second, "valores finais idênticos após reimport"
    end

    # F3.2.1 — regressão do bug de merge com last_ts nulo.
    test "todas as linhas com last_ts nil: primeira linha vence escalares (ordem de leitura)" do
      rows = [
        { thread_id: "tn-1", source: "codex_session", workspace_hash: "wsA", title: "Primeiro título",
          message_count: 2, user_turns: 1, assistant_turns: 1, tool_calls: 0, files_changed: [ "a.rb" ],
          first_ts: nil, last_ts: nil },
        { thread_id: "tn-1", source: "claude_code_session", workspace_hash: "wsB", title: "Segundo título",
          message_count: 5, user_turns: 3, assistant_turns: 2, tool_calls: 1, files_changed: [ "b.rb" ],
          first_ts: nil, last_ts: nil }
      ]
      import_lines(rows)
      c = Conversation.find_by!(thread_id: "tn-1")

      assert_equal "codex_session", c.source, "escalares da primeira linha (ordem de leitura)"
      assert_equal "wsA", c.workspace_hash
      assert_equal "Primeiro título", c.title
      assert_equal 5, c.message_count, "contadores = maior valor"
      assert_equal 3, c.user_turns
      assert_equal [ "a.rb", "b.rb" ], c.files_changed, "união distinta ordenada"
      assert_nil c.last_ts

      # idempotência: reimportar não duplica nem altera os escalares
      run2 = import_lines(rows)
      assert_equal 0, run2.imported
      assert_equal 1, Conversation.where(thread_id: "tn-1").count
      assert_equal "codex_session", Conversation.find_by!(thread_id: "tn-1").source
    end

    test "linha com last_ts real vence escalares sobre linha anterior com last_ts nil" do
      rows = [
        { thread_id: "tm-1", source: "codex_session", workspace_hash: "wsNIL", title: "Título nil-ts",
          message_count: 1, files_changed: [], first_ts: nil, last_ts: nil },
        { thread_id: "tm-1", source: "claude_code_session", workspace_hash: "wsREAL", title: "Título real",
          message_count: 3, files_changed: [], first_ts: "2026-03-01T10:00:00+00:00", last_ts: "2026-03-01T11:00:00+00:00" }
      ]
      import_lines(rows)
      c = Conversation.find_by!(thread_id: "tm-1")

      assert_equal "claude_code_session", c.source, "linha com last_ts real vence"
      assert_equal "wsREAL", c.workspace_hash
      assert_equal "Título real", c.title
      assert_equal Time.utc(2026, 3, 1, 11, 0, 0).to_i, c.last_ts.to_i
    end

    test "backfill: registro existente com escalares nil é preenchido no reimport" do
      nil_row = { thread_id: "bf-1", source: nil, workspace_hash: nil, title: nil,
                  message_count: 1, files_changed: [], first_ts: nil, last_ts: nil }
      # 1ª importação: sem source/ws (simula o estado defeituoso anterior)
      import_lines([ nil_row ])
      assert_nil Conversation.find_by!(thread_id: "bf-1").source

      # 2ª importação: agora a linha traz source/ws (last_ts ainda nil) → backfill
      import_lines([ nil_row.merge(source: "codex_session", workspace_hash: "wsBF", title: "Título BF") ])
      c = Conversation.find_by!(thread_id: "bf-1")
      assert_equal "codex_session", c.source, "backfill de escalar antes nulo"
      assert_equal "wsBF", c.workspace_hash
      assert_equal "Título BF", c.title
      assert_equal 1, Conversation.where(thread_id: "bf-1").count
    end
  end
end
