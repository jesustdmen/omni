require "test_helper"

# PB-020 (Triagem) — atividade de 2º nível (rascunho manual da conversa).
class ConversationActivityDraftTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  def draft(**attrs)
    @conversation.activity_drafts.new({ title: "Atividade X" }.merge(attrs))
  end

  test "default status é draft (Rascunho) e source manual" do
    d = draft
    assert d.valid?
    assert_equal "draft", d.status
    assert_equal "manual", d.source
    assert_equal "Rascunho", d.status_label
  end

  test "título é obrigatório (e trim)" do
    assert_not draft(title: "   ").valid?
  end

  test "status fora da lista permitida é rejeitado" do
    d = draft(status: "done")
    assert_not d.valid?
    assert d.errors[:status].any?
  end

  test "aceita source manual e ia_local" do
    assert draft(source: "manual").valid?
    assert draft(source: "ia_local").valid?
  end

  test "source fora da lista permitida é rejeitado" do
    d = draft(source: "gemma")
    assert_not d.valid?
    assert d.errors[:source].any?
  end

  test "rótulos PT-BR das fontes" do
    assert_equal "Manual", draft(source: "manual").source_label
    assert_equal "IA local", draft(source: "ia_local").source_label
  end

  test "rótulos PT-BR dos status" do
    assert_equal "Rascunho", draft(status: "draft").status_label
    assert_equal "Confirmada", draft(status: "confirmed").status_label
    assert_equal "Descartada", draft(status: "discarded").status_label
  end

  test "ordered ordena por position" do
    b = @conversation.activity_drafts.create!(title: "B", position: 2)
    a = @conversation.activity_drafts.create!(title: "A", position: 1)
    assert_equal [ a.id, b.id ], @conversation.activity_drafts.ordered.pluck(:id)
  end

  test "ao destruir a conversa, as atividades somem" do
    @conversation.activity_drafts.create!(title: "X")
    assert_difference("ConversationActivityDraft.count", -1) { @conversation.destroy }
  end
end
