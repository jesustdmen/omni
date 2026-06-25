require "test_helper"

# PB-020 (Triagem) — ConversationTimeline: gaps derivados de conversation_turn_refs.ts
# (do índice no banco; sem ler o arquivo). Read-only; só evidência visual.
class ConversationTimelineTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 0, user_turns: 0, assistant_turns: 0, tool_calls: 0)
    @source = TurnSource.create!(source_file: "/normalized/sessions.jsonl",
                                 source_label: "sessions.jsonl", content_hash: "h-#{SecureRandom.hex(4)}",
                                 schema_version: "v1", size_bytes: 100, source_mtime: Time.current, status: "ok")
    @line = 0
  end

  # Cria um turn_ref com timestamp (ou nil), em ordem de linha.
  def ref(ts)
    @line += 1
    ConversationTurnRef.create!(conversation: @conversation, turn_source: @source,
                               thread_id: @conversation.thread_id, line_no: @line,
                               byte_offset: @line * 100, role: "user", ts: ts)
  end

  test "detecta gap acima de 15 min entre turnos consecutivos" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    ref(base)
    ref(base + 20.minutes) # gap de 20 min
    tl = ConversationTimeline.call(conversation: @conversation)
    assert_equal 1, tl.gaps.size
    assert_equal 1200, tl.gaps.first.seconds
    assert tl.any_gaps?
  end

  test "gap menor ou igual a 15 min NÃO aparece" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    ref(base)
    ref(base + 15.minutes)      # exatamente 15 min → não conta (limiar é > 15)
    ref(base + 15.minutes + 5.minutes) # +5 min → também ≤15 do anterior → não conta
    tl = ConversationTimeline.call(conversation: @conversation)
    assert_empty tl.gaps
    assert_not tl.any_gaps?
  end

  test "timestamps nil não quebram e não geram gap" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    ref(base)
    ref(nil)                    # turno sem ts no meio
    ref(base + 30.minutes)      # 30 min após o ÚLTIMO com ts (não após o nil)
    tl = ConversationTimeline.call(conversation: @conversation)
    assert_equal 1, tl.gaps.size
    assert_equal 1800, tl.gaps.first.seconds
  end

  test "tudo nil: sem gaps, sem erro" do
    ref(nil); ref(nil); ref(nil)
    tl = ConversationTimeline.call(conversation: @conversation)
    assert_empty tl.gaps
  end

  test "gaps_by_line indexa pelo line_no do turno anterior" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    r1 = ref(base)
    ref(base + 25.minutes)
    tl = ConversationTimeline.call(conversation: @conversation)
    assert tl.gaps_by_line.key?(r1.line_no)
  end

  test "limiar configurável" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    ref(base); ref(base + 5.minutes)
    assert_empty ConversationTimeline.call(conversation: @conversation).gaps # default >15min
    tl = ConversationTimeline.call(conversation: @conversation, threshold_seconds: 60) # >1min
    assert_equal 1, tl.gaps.size
  end

  test "read-only: não cria nada" do
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    ref(base); ref(base + 30.minutes)
    assert_no_difference([ "ConversationTurnRef.count", "TimeEntry.count" ]) do
      ConversationTimeline.call(conversation: @conversation)
    end
  end
end
