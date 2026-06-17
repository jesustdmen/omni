require "test_helper"

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
  end
end
