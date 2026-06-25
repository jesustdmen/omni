require "test_helper"

# IA local — montagem do contexto textual seguro. Testado com um LOADER FAKE
# (sem arquivo real / sem índice): valida marcadores, redação de PII, truncagem,
# bloqueio de conversa pessoal, loader stale/indisponível e seleção início+fim.
class Ai::ConversationContextBuilderTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 0, user_turns: 0, assistant_turns: 0, tool_calls: 0)
  end

  def turn(line_no, role, text)
    ConversationTurns::LazyLoader::Turn.new(line_no: line_no, role: role, text: text)
  end

  # Loader fake: devolve Result com status/turns; respeita limit/offset.
  class LoaderFake
    def initialize(status:, turns: [], total: nil)
      @status = status
      @turns = turns
      @total = total || turns.size
    end

    def call(conversation_id:, limit: nil, offset: 0, roles: nil)
      base = roles ? @turns.select { |t| roles.include?(t.role.to_s) } : @turns
      sel = base.drop(offset)
      sel = sel.first(limit) if limit
      ConversationTurns::LazyLoader::Result.new(
        status: @status, turns: sel, total: (roles ? base.size : @total), limit: limit, offset: offset, mismatched: 0, turn_source: nil
      )
    end
  end

  test "inclui trechos reais de usuário/assistente com marcadores e ordem cronológica" do
    loader = LoaderFake.new(status: :ok, turns: [
      turn(1, "user", "Preciso validar 142 notas de entrada"),
      turn(2, "assistant", "Validei as 142 notas e ajustei 3 XMLs")
    ])
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert r.present?
    assert_equal 2, r.turns_used
    assert_match(/Turno 1 — usuário:\nPreciso validar 142 notas/, r.text)
    assert_match(/Turno 2 — assistente:\nValidei as 142 notas/, r.text)
    assert_operator r.text.index("Turno 1"), :<, r.text.index("Turno 2")
  end

  test "aplica redação de PII no texto dos turnos" do
    loader = LoaderFake.new(status: :ok, turns: [ turn(1, "user", "meu email é joao@example.com") ])
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert_match "<EMAIL>", r.text
    assert_no_match(/joao@example\.com/, r.text)
  end

  test "ignora turnos de ferramenta (tool)" do
    loader = LoaderFake.new(status: :ok, turns: [
      turn(1, "tool", "saída enorme de ferramenta"),
      turn(2, "user", "mensagem real")
    ])
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert_equal 1, r.turns_used
    assert_no_match(/ferramenta/, r.text)
    assert_match(/mensagem real/, r.text)
  end

  test "trunca texto por turno acima do limite" do
    grande = "x" * (Ai::ConversationContextBuilder::MAX_TURN_CHARS + 500)
    loader = LoaderFake.new(status: :ok, turns: [ turn(1, "user", grande) ])
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert_match(/… \(truncado\)/, r.text)
    assert_operator r.text.length, :<, grande.length
  end

  test "conversa pessoal retorna contexto vazio (não envia conteúdo)" do
    @conversation.update!(personal: true)
    loader = LoaderFake.new(status: :ok, turns: [ turn(1, "user", "conteúdo sensível") ])
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert r.vazio?
    assert_equal :personal, r.status
    assert_equal "", r.text
  end

  test "loader stale retorna contexto vazio controlado" do
    loader = LoaderFake.new(status: :stale, turns: [], total: 10)
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert r.vazio?
    assert_equal :indisponivel, r.status
  end

  test "loader vazio (sem turnos) retorna contexto vazio" do
    loader = LoaderFake.new(status: :ok, turns: [], total: 0)
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert r.vazio?
  end

  test "conversa enorme seleciona início e fim (descarta o miolo)" do
    turns = (1..70).map { |i| turn(i, "user", "linha #{i}") }
    loader = LoaderFake.new(status: :ok, turns: turns, total: 70)
    r = Ai::ConversationContextBuilder.call(conversation: @conversation, loader: loader)

    assert_match(/Turno 1 —/, r.text)   # início
    assert_match(/Turno 70 —/, r.text)  # fim
    assert_no_match(/Turno 35 —/, r.text) # miolo descartado
    assert_operator r.turns_used, :<=, Ai::ConversationContextBuilder::MAX_TURNS
  end
end
