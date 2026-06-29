require "test_helper"

# PB-020d (Triagem) — bloco de trabalho (rascunho por turno/dia da conversa).
class ConversationWorkBlockTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  def block(**attrs)
    @conversation.work_blocks.new({ period_date: Date.new(2026, 6, 29), day_period: "manha" }.merge(attrs))
  end

  test "defaults: kind execution, status draft, source manual, duration 0" do
    b = block
    assert b.valid?
    assert_equal "execution", b.kind
    assert_equal "draft", b.status
    assert_equal "manual", b.source
    assert_equal 0, b.duration_seconds
  end

  test "period_date é obrigatório" do
    assert_not block(period_date: nil).valid?
  end

  test "day_period exige lista permitida (manha|tarde|noite)" do
    assert block(day_period: "tarde").valid?
    assert_not block(day_period: "madrugada").valid?
  end

  test "kind exige lista permitida (execution|gap)" do
    assert block(kind: "gap").valid?
    assert_not block(kind: "analysis").valid?
  end

  test "status exige lista permitida" do
    assert block(status: "confirmed").valid?
    assert_not block(status: "done").valid?
  end

  test "source exige lista permitida" do
    assert block(source: "ia_local").valid?
    assert_not block(source: "gemma").valid?
  end

  test "duration_seconds não pode ser negativa" do
    assert_not block(duration_seconds: -1).valid?
    assert block(duration_seconds: 3600).valid?
  end

  test "fim não pode ser anterior ao início; tempo é opcional (evidência)" do
    base = Time.utc(2026, 6, 29, 11)
    assert_not block(start_time: base, end_time: base - 1.hour).valid?
    assert block(start_time: base, end_time: base + 1.hour).valid?
    assert block(start_time: nil, end_time: nil).valid?
  end

  test "client/project/task são opcionais (rascunho não exige task)" do
    assert block(client_id: nil, project_id: nil, task_id: nil).valid?
  end

  test "rótulos PT-BR" do
    assert_equal "Manhã", block(day_period: "manha").day_period_label
    assert_equal "Execução", block(kind: "execution").kind_label
    assert_equal "Gap", block(kind: "gap").kind_label
    assert_equal "Rascunho", block(status: "draft").status_label
    assert_equal "IA local", block(source: "ia_local").source_label
  end

  test "ordered ordena por period_date e position" do
    b2 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 30), day_period: "manha", position: 0)
    b1 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "tarde", position: 1)
    b0 = @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "manha", position: 0)
    assert_equal [ b0.id, b1.id, b2.id ], @conversation.work_blocks.ordered.pluck(:id)
  end

  test "conversa pessoal não permite bloco (backstop de modelo)" do
    @conversation.update!(personal: true)
    b = block
    assert_not b.valid?
    assert b.errors[:base].any?
  end

  test "normaliza summary/notes vazios para nil" do
    b = block(summary: "   ", notes: "")
    b.valid?
    assert_nil b.summary
    assert_nil b.notes
  end

  test "ao destruir a conversa, os blocos somem" do
    @conversation.work_blocks.create!(period_date: Date.new(2026, 6, 29), day_period: "manha")
    assert_difference("ConversationWorkBlock.count", -1) { @conversation.destroy }
  end
end
