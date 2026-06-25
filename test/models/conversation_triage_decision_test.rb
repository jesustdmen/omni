require "test_helper"

# PB-020 (Triagem persistida mínima) — decisão humana de triagem (model).
class ConversationTriageDecisionTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  test "default status é open e válido" do
    d = ConversationTriageDecision.create!(conversation: @conversation)
    assert_equal "open", d.status
  end

  test "status fora da lista permitida é rejeitado" do
    d = ConversationTriageDecision.new(conversation: @conversation, status: "done")
    assert_not d.valid?
    assert d.errors[:status].any?, "status inválido deveria gerar erro"
  end

  test "aceita reviewed e ignored" do
    %w[open reviewed ignored].each do |s|
      d = ConversationTriageDecision.new(conversation: Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
        message_count: 0, user_turns: 0, assistant_turns: 0, tool_calls: 0), status: s)
      assert d.valid?, "status #{s} deveria ser válido"
    end
  end

  test "conversation_id é único (1:1)" do
    ConversationTriageDecision.create!(conversation: @conversation)
    dup = ConversationTriageDecision.new(conversation: @conversation)
    assert_not dup.valid?
    assert dup.errors[:conversation_id].any?, "conversation_id duplicado deveria gerar erro"
  end

  test "cliente/projeto confirmados são opcionais" do
    d = ConversationTriageDecision.create!(conversation: @conversation, status: "reviewed")
    assert_nil d.confirmed_client
    assert_nil d.confirmed_project
  end

  test "projeto confirmado deve pertencer ao cliente confirmado" do
    cli = Client.create!(name: "ACME")
    outro = Client.create!(name: "Outro")
    proj = outro.projects.create!(name: "P", status: "planning")
    d = ConversationTriageDecision.new(conversation: @conversation, confirmed_client: cli, confirmed_project: proj)
    assert_not d.valid?
    assert_includes d.errors[:confirmed_project], "deve pertencer ao cliente confirmado"
  end

  test "projeto coerente com o cliente é aceito" do
    cli = Client.create!(name: "ACME")
    proj = cli.projects.create!(name: "P", status: "planning")
    d = ConversationTriageDecision.new(conversation: @conversation, confirmed_client: cli, confirmed_project: proj)
    assert d.valid?
  end

  test "usa a tabela conversation_triages" do
    assert_equal "conversation_triages", ConversationTriageDecision.table_name
  end

  test "ao destruir a conversa, a decisão some (1:1 dependent destroy)" do
    ConversationTriageDecision.create!(conversation: @conversation)
    assert_difference("ConversationTriageDecision.count", -1) { @conversation.destroy }
  end
end
