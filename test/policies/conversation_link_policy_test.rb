require "test_helper"

class ConversationLinkPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
    @conv = Conversation.create!(thread_id: "t-1", source: "codex_session")
    @link = ConversationLink.create!(conversation: @conv, task: @task, link_type: "primary")
  end

  test "usuário autenticado pode criar/remover/ver" do
    assert ConversationLinkPolicy.new(@user, @link).create?
    assert ConversationLinkPolicy.new(@user, @link).destroy?
    assert ConversationLinkPolicy.new(@user, @link).show?
  end

  test "anônimo não pode" do
    assert_not ConversationLinkPolicy.new(nil, @link).create?
    assert_not ConversationLinkPolicy.new(nil, @link).destroy?
  end
end
