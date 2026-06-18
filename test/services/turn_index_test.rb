require "test_helper"
require "json"
require "tempfile"

# Cobre a fatia pré-F5 (ADR-021): índice de offsets (Sync::BuildConversationTurnRefs)
# + leitura lazy (ConversationTurns::LazyLoader). Usa um sessions.jsonl temporário e
# determinístico (não processa o arquivo real de 229 MiB).
class TurnIndexTest < ActiveSupport::TestCase
  setup do
    @conv_a = Conversation.create!(thread_id: "tA", source: "claude_code_session", message_count: 3)
    @conv_b = Conversation.create!(thread_id: "tB", source: "claude_code_session", message_count: 1)
    @path = write_sessions(default_lines)
  end

  teardown do
    File.unlink(@path) if @path && File.exist?(@path)
  end

  # role/text/tool_input presentes nas linhas para provar que NÃO são persistidos.
  def default_lines
    [
      line(thread_id: "tA", role: "user", text: "Olá A1", raw: "C:\\Users\\Jesus\\proj\\x"),
      line(thread_id: "tB", role: "user", text: "B1"),
      line(thread_id: "tA", role: "assistant", text: "Resp A2", tool: "edit",
           tool_input: { "file" => "a.rb" }, files_changed: [ "a.rb" ]),
      "{ isto nao e json valido",                              # malformada
      line(thread_id: "tNoConv", role: "user", text: "sem conversa"),
      '{"role":"user","text":"sem thread"}',                  # sem thread_id
      line(thread_id: "tA", role: "tool", text: "tool A3")
    ]
  end

  def line(thread_id:, role:, text:, tool: nil, tool_input: nil, files_changed: [], raw: "SYNTHETIC/x")
    JSON.generate(
      "source" => "claude_code_session", "session_id" => thread_id, "thread_id" => thread_id,
      "timestamp" => "2026-01-10T09:00:00+00:00", "role" => role, "text" => text,
      "tool" => tool, "tool_input" => tool_input, "files_changed" => files_changed,
      "model_id" => "synthetic", "raw_source_file" => raw
    )
  end

  def write_sessions(lines)
    f = Tempfile.create([ "sessions", ".jsonl" ])
    f.binmode
    f.write(lines.join("\n"))
    f.flush
    f.close
    f.path
  end

  def build(path = @path)
    Sync::BuildConversationTurnRefs.call(path: path)
  end

  # 1. migration/model básico
  test "models e colunas existem; cria registros básicos" do
    src = TurnSource.create!(source_label: "sessions.jsonl", source_file: "/x", size_bytes: 1,
                             source_mtime: Time.current, content_hash: "h", schema_version: "4")
    ref = ConversationTurnRef.create!(turn_source: src, conversation: @conv_a, thread_id: "tA",
                                      line_no: 1, byte_offset: 0)
    assert ref.persisted?
    assert_equal [ "pending" ], [ src.status ]
  end

  # 2. fingerprint igual → no-op idempotente
  test "fingerprint igual gera no-op idempotente" do
    build
    sources = TurnSource.count
    refs = ConversationTurnRef.count
    r2 = build
    assert r2.no_op, "segunda execução deveria ser no-op"
    assert_equal sources, TurnSource.count
    assert_equal refs, ConversationTurnRef.count
  end

  # 3. fingerprint diferente → rebuild substitui versão antiga
  test "fingerprint diferente reconstrói e remove versão antiga" do
    build
    old_id = TurnSource.first.id
    File.open(@path, "ab") { |f| f.write("\n" + line(thread_id: "tB", role: "assistant", text: "B2")) }
    r = build
    assert_not r.no_op
    assert_equal 1, TurnSource.count, "versão antiga deve ser removida"
    assert_not_equal old_id, TurnSource.first.id
    assert_equal 0, ConversationTurnRef.where(turn_source_id: old_id).count
  end

  # 3b. loader detecta índice obsoleto (stale) sem rebuild
  test "loader retorna stale quando o arquivo muda sem rebuild" do
    build
    File.open(@path, "ab") { |f| f.write("\n" + line(thread_id: "tA", role: "user", text: "A4")) }
    res = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path)
    assert_equal :stale, res.status
  end

  # 4. offset correto: seek + gets retorna a linha esperada
  test "byte_offset aponta para a linha correta" do
    build
    ref = ConversationTurnRef.where(conversation: @conv_a).order(:line_no).first
    File.open(@path, "rb") do |f|
      f.seek(ref.byte_offset)
      parsed = JSON.parse(f.gets.force_encoding("UTF-8"))
      assert_equal "tA", parsed["thread_id"]
      assert_equal "Olá A1", parsed["text"]
    end
  end

  # 5. linha malformada não derruba
  test "linha malformada é contada e não derruba o build" do
    r = build
    assert_equal 1, r.malformed_lines
    assert_operator r.refs_created, :>, 0
  end

  # 6. thread_id sem conversation vira skip
  test "thread sem conversation é pulada" do
    r = build
    assert_equal 1, r.skipped_no_conversation
    assert_equal 0, ConversationTurnRef.where(thread_id: "tNoConv").count
  end

  # 7. text não é persistido
  test "coluna text não existe em conversation_turn_refs" do
    assert_not ConversationTurnRef.column_names.include?("text")
  end

  # 8. tool_input não é persistido
  test "coluna tool_input não existe em conversation_turn_refs" do
    assert_not ConversationTurnRef.column_names.include?("tool_input")
    assert_empty ConversationTurnRef.column_names & %w[raw_content payload content]
  end

  # 9. loader lê apenas refs da conversa
  test "loader retorna somente turnos da conversa" do
    build
    res = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path)
    assert_equal :ok, res.status
    assert_equal 3, res.turns.size
    assert(res.turns.all? { |t| %w[user assistant tool].include?(t.role) })
    assert_equal [ "Olá A1", "Resp A2", "tool A3" ], res.turns.map(&:text)
  end

  # 10. loader valida thread_id (offset obsoleto aponta para outra conversa)
  test "loader descarta linha cujo thread_id não bate" do
    build
    ref = ConversationTurnRef.where(conversation: @conv_a).order(:line_no).first
    bad_offset = ConversationTurnRef.where(conversation: @conv_b).first.byte_offset
    ref.update_columns(byte_offset: bad_offset) # aponta para linha da conversa B
    res = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path)
    assert_operator res.mismatched, :>=, 1
    assert_equal 2, res.turns.size
  end

  # 11. loader suporta limit e offset
  test "loader respeita limit e offset" do
    build
    first = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path, limit: 1)
    assert_equal 1, first.turns.size
    assert_equal "Olá A1", first.turns.first.text
    assert_equal 3, first.total

    skipped = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path, offset: 1)
    assert_equal 2, skipped.turns.size
    assert_equal "Resp A2", skipped.turns.first.text
  end

  # 12. raw_source_file redigido
  test "raw_source_file tem usuário redigido" do
    build
    res = ConversationTurns::LazyLoader.call(conversation_id: @conv_a.id, path: @path)
    src = res.turns.first.source_file
    assert_includes src, "<USER>"
    assert_not_includes src, "Jesus"
  end

  # 13. refs batem com message_count por amostra
  test "refs da conversa batem com message_count" do
    build
    assert_equal @conv_a.message_count, ConversationTurnRef.where(conversation: @conv_a).count
  end

  # Código-fonte sem comentários (os comentários citam "shards"/"ImportSummaries" só para
  # documentar o escopo negativo; aqui validamos que o CÓDIGO não os usa).
  def code_only(rel)
    File.read(Rails.root.join(rel)).each_line.map { |l| l.sub(/#.*$/, "") }.join
  end

  # 14. não lê shards (código não referencia shards; build usa só o sessions.jsonl)
  test "não lê shards" do
    r = build
    assert_operator r.refs_created, :>, 0
    assert_no_match(/shard/i, code_only("app/services/sync/build_conversation_turn_refs.rb"))
    assert_no_match(/shard/i, code_only("app/services/conversation_turns/lazy_loader.rb"))
  end

  # 15. não executa sync de summaries; não cria conversas
  test "não executa sync de summaries nem cria conversas" do
    assert_no_difference -> { Conversation.count } do
      build
    end
    assert_equal 0, SyncRun.where(source_label: "summaries.jsonl").count
    assert_no_match(/ImportSummaries|ResolveWorkspaceFolders|summaries\.jsonl/,
                    code_only("app/services/sync/build_conversation_turn_refs.rb"))
  end
end
