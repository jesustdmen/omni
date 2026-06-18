require "test_helper"
require "json"
require "tempfile"

# F5.1 — render read-only de turnos em /conversations/:id (ADR-021/ADR-012).
# Usa um sessions.jsonl temporário + Sync::BuildConversationTurnRefs (como em
# turn_index_test.rb); não toca o arquivo real de 229 MiB.
class ConversationTurnsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
  end

  teardown do
    File.unlink(@path) if @path && File.exist?(@path)
  end

  def line(thread_id:, role:, text:, tool: nil, tool_input: nil, raw: "SYNTHETIC/x")
    JSON.generate(
      "source" => "claude_code_session", "session_id" => thread_id, "thread_id" => thread_id,
      "timestamp" => "2026-01-10T09:00:00+00:00", "role" => role, "text" => text,
      "tool" => tool, "tool_input" => tool_input, "files_changed" => [],
      "model_id" => "m", "raw_source_file" => raw
    )
  end

  def build_for(lines)
    @path = Tempfile.create([ "sessions", ".jsonl" ]).then do |f|
      f.binmode
      f.write(lines.join("\n"))
      f.flush
      f.close
      f.path
    end
    Sync::BuildConversationTurnRefs.call(path: @path)
  end

  test "renderiza turnos read-only da conversa" do
    conv = Conversation.create!(thread_id: "tA", source: "claude_code_session", message_count: 2)
    build_for([
      line(thread_id: "tA", role: "user", text: "Olá mundo"),
      line(thread_id: "tA", role: "assistant", text: "Resposta", tool: "edit", tool_input: { "f" => "a.rb" })
    ])
    get conversation_path(conv)
    assert_response :success
    assert_select "ol.turns li.turn", 2
    assert_match "Olá mundo", response.body
    assert_select "pre.turn__pre", /a\.rb/
    assert_select ".turn__role", /User/
  end

  test "sanitiza payload XSS (conteúdo não confiável é escapado)" do
    conv = Conversation.create!(thread_id: "tX", source: "x", message_count: 1)
    build_for([
      line(thread_id: "tX", role: "user", text: "<script>alert(1)</script>",
           tool_input: { "x" => "\"><img src=x onerror=alert(1)>" })
    ])
    get conversation_path(conv)
    assert_response :success
    assert_no_match(%r{<script>alert\(1\)</script>}, response.body)
    assert_match "&lt;script&gt;", response.body
    assert_no_match(/<img[^>]*onerror=/, response.body)
  end

  test "pagina turnos com PER_PAGE=50" do
    conv = Conversation.create!(thread_id: "tP", source: "x", message_count: 55)
    build_for((1..55).map { |i| line(thread_id: "tP", role: "user", text: "linha #{i}") })
    get conversation_path(conv)
    assert_select "ol.turns li.turn", 50
    assert_select "nav.pager"
    assert_match "Página 1 de 2", response.body

    get conversation_path(conv, turn_page: 2)
    assert_select "ol.turns li.turn", 5
  end

  test "índice obsoleto (stale) não renderiza turnos" do
    conv = Conversation.create!(thread_id: "tS", source: "x", message_count: 1)
    build_for([ line(thread_id: "tS", role: "user", text: "antes") ])
    File.open(@path, "ab") { |f| f.write("\n" + line(thread_id: "tS", role: "user", text: "depois")) }
    get conversation_path(conv)
    assert_response :success
    assert_match "desatualizado", response.body
    assert_select "ol.turns", count: 0
  end

  test "conversa sem refs mostra aviso de índice não construído" do
    conv = Conversation.create!(thread_id: "tE", source: "x", message_count: 0)
    get conversation_path(conv)
    assert_response :success
    assert_match "Índice de turnos ainda não construído", response.body
    assert_select "ol.turns", count: 0
  end

  test "b1: conversa pessoal oculta conteúdo dos turnos" do
    conv = Conversation.create!(thread_id: "tPer", source: "x", personal: true, message_count: 1)
    build_for([ line(thread_id: "tPer", role: "user", text: "segredo pessoal") ])
    get conversation_path(conv)
    assert_response :success
    assert_match "pessoal", response.body
    assert_not_includes response.body, "segredo pessoal"
    assert_select "ol.turns", count: 0
  end

  test "abrir a conversa não persiste conteúdo de turnos" do
    conv = Conversation.create!(thread_id: "tN", source: "x", message_count: 1)
    build_for([ line(thread_id: "tN", role: "user", text: "oi") ])
    assert_no_difference "ConversationTurnRef.count" do
      get conversation_path(conv)
    end
    assert_empty ConversationTurnRef.column_names & %w[text tool_input payload raw_content content]
  end

  test "não vaza source_file nem PII de caminho" do
    conv = Conversation.create!(thread_id: "tF", source: "x", message_count: 1)
    build_for([ line(thread_id: "tF", role: "user", text: "oi", raw: "C:\\Users\\Jesus\\proj\\x.jsonl") ])
    get conversation_path(conv)
    assert_response :success
    assert_not_includes response.body, "Jesus"
    assert_not_includes response.body, @path
  end

  test "grep-guard: views/componentes de turno não usam html_safe/raw/sanitize" do
    rels = [
      "app/components/conversations/turn_list_component.rb",
      "app/components/conversations/turn_list_component.html.erb",
      "app/views/conversations/show.html.erb"
    ]
    rels.each do |rel|
      code = File.read(Rails.root.join(rel)).each_line.map { |l| l.sub(/#.*$/, "") }.join
      assert_no_match(/\bhtml_safe\b|\braw\b|<%==|\bsimple_format\b|\bsanitize\b/, code, rel)
    end
  end
end
