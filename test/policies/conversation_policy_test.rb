require "test_helper"

# Lacuna coberta na F5.1: ConversationPolicy (única policy de leitura sem teste).
# ADR-014 — domínio compartilhado no MVP (qualquer usuário autenticado lê).
class ConversationPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "p", email: "p@example.com", password: "secret12345")
    @conv = Conversation.create!(thread_id: "t-policy-1", source: "x")
  end

  test "autenticado pode index? e show?" do
    policy = ConversationPolicy.new(@user, @conv)
    assert policy.index?
    assert policy.show?
  end

  test "anônimo não pode index? nem show?" do
    policy = ConversationPolicy.new(nil, @conv)
    assert_not policy.index?
    assert_not policy.show?
  end

  test "Scope: autenticado vê todas; anônimo nenhuma" do
    Conversation.create!(thread_id: "t-policy-2", source: "x")
    assert_equal Conversation.count, ConversationPolicy::Scope.new(@user, Conversation).resolve.count
    assert_equal 0, ConversationPolicy::Scope.new(nil, Conversation).resolve.count
  end
end
