require "test_helper"

class ConversationLinkTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T1", type: "support")
    @task2 = @client.tasks.create!(title: "T2", type: "support")
    @conv = Conversation.create!(thread_id: "t-1", source: "codex_session", last_ts: Time.utc(2026, 1, 1, 10, 0, 0))
    @conv2 = Conversation.create!(thread_id: "t-2", source: "agent_sessions", last_ts: Time.utc(2026, 2, 1, 10, 0, 0))
    @personal = Conversation.create!(thread_id: "t-p", source: "x", personal: true, last_ts: Time.utc(2026, 3, 1, 0, 0, 0))
  end

  def link(attrs = {})
    ConversationLink.new({ conversation: @conv, task: @task, link_type: "primary", origin: "manual" }.merge(attrs))
  end

  # --- model / DB ---
  test "cria link primary válido" do
    assert link.valid?
    assert link.save
  end

  test "impede segundo primary para a mesma conversa" do
    link.save!
    dup = link(task: @task2, link_type: "primary")
    assert_not dup.valid?
    assert dup.errors[:link_type].any?
  end

  test "permite mention junto com primary" do
    link.save!
    assert link(task: @task2, link_type: "mention").valid?
  end

  test "impede duplicata exata (conversation, task, link_type)" do
    link(link_type: "mention").save!
    assert_not link(link_type: "mention").valid?
  end

  test "valida link_type" do
    assert_not link(link_type: "bogus").valid?
  end

  test "valida origin" do
    assert_not link(origin: "bogus").valid?
  end

  test "confidence deve estar entre 0 e 1 quando presente" do
    assert_not link(confidence: 1.5).valid?
    assert_not link(confidence: -0.1).valid?
    assert link(confidence: 0.5).valid?
    assert link(confidence: nil).valid?
  end

  test "cascade ao excluir conversation e task" do
    link.save!
    assert_difference "ConversationLink.count", -1 do
      @conv.destroy
    end
    ConversationLink.create!(conversation: @conv2, task: @task, link_type: "primary")
    assert_difference "ConversationLink.count", -1 do
      @task.destroy
    end
  end

  # --- counters em Task ---
  test "criar primary não-personal incrementa conversation_count e atualiza last_conversation_at" do
    ConversationLink.create!(conversation: @conv, task: @task, link_type: "primary")
    assert_equal 1, @task.reload.conversation_count
    assert_equal @conv.last_ts.to_i, @task.last_conversation_at.to_i
  end

  test "last_conversation_at usa o maior last_ts entre as conversas primárias" do
    ConversationLink.create!(conversation: @conv, task: @task, link_type: "primary")
    ConversationLink.create!(conversation: @conv2, task: @task, link_type: "primary")
    assert_equal 2, @task.reload.conversation_count
    assert_equal @conv2.last_ts.to_i, @task.last_conversation_at.to_i
  end

  test "remover primary recalcula counters" do
    l1 = ConversationLink.create!(conversation: @conv, task: @task, link_type: "primary")
    ConversationLink.create!(conversation: @conv2, task: @task, link_type: "primary")
    l1.destroy
    assert_equal 1, @task.reload.conversation_count
    assert_equal @conv2.last_ts.to_i, @task.last_conversation_at.to_i
  end

  test "mention não altera counter" do
    ConversationLink.create!(conversation: @conv, task: @task, link_type: "mention")
    assert_equal 0, @task.reload.conversation_count
    assert_nil @task.last_conversation_at
  end

  test "conversa personal não altera counter" do
    ConversationLink.create!(conversation: @personal, task: @task, link_type: "primary")
    assert_equal 0, @task.reload.conversation_count
    assert_nil @task.last_conversation_at
  end
end
