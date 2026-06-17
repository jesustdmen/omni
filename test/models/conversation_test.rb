require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "thread_id obrigatório" do
    conversation = Conversation.new(thread_id: nil)
    assert_not conversation.valid?
    assert conversation.errors[:thread_id].any?
  end

  test "thread_id único" do
    Conversation.create!(thread_id: "t-1")
    dup = Conversation.new(thread_id: "t-1")
    assert_not dup.valid?
    assert dup.errors[:thread_id].any?
  end

  test "defaults de contadores, files_changed e personal" do
    conversation = Conversation.create!(thread_id: "t-defaults")
    assert_equal 0, conversation.message_count
    assert_equal 0, conversation.user_turns
    assert_equal 0, conversation.assistant_turns
    assert_equal 0, conversation.tool_calls
    assert_equal [], conversation.files_changed
    assert_equal false, conversation.personal
  end

  test "contadores não podem ser negativos" do
    assert_not Conversation.new(thread_id: "t-neg", message_count: -1).valid?
  end

  test "user é opcional" do
    assert Conversation.new(thread_id: "t-nouser").valid?
  end

  test "aceita thread_id estilo sha1/40-hex (text, não uuid)" do
    assert Conversation.new(thread_id: "a1b2c3d4e5f60718293a4b5c6d7e8f9000112233").valid?
  end
end
