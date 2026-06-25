require "test_helper"

# PB-020 (Triagem persistida mínima) — persistir decisão humana via PATCH.
class ConversationTriageDecisionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @conversation = Conversation.create!(thread_id: "t-#{SecureRandom.hex(4)}",
                                         message_count: 1, user_turns: 1, assistant_turns: 0, tool_calls: 0)
  end

  test "exige autenticação" do
    sign_out @user
    patch conversation_triage_path(@conversation), params: { status: "reviewed" }
    assert_redirected_to new_user_session_path
  end

  test "marcar revisada persiste status e auditoria (triaged_by)" do
    patch conversation_triage_path(@conversation), params: { status: "reviewed" }
    assert_response :redirect
    d = @conversation.reload.triage
    assert_equal "reviewed", d.status
    assert_equal @user.id, d.triaged_by_id
  end

  test "ignorar e reabrir" do
    patch conversation_triage_path(@conversation), params: { status: "ignored" }
    assert_equal "ignored", @conversation.reload.triage.status
    patch conversation_triage_path(@conversation), params: { status: "open" }
    assert_equal "open", @conversation.reload.triage.status
  end

  test "status fora da lista permitida é ignorado (mantém o atual)" do
    patch conversation_triage_path(@conversation), params: { status: "reviewed" }
    patch conversation_triage_path(@conversation), params: { status: "lixo" }
    # não aplica status inválido: continua reviewed (não cria estado invalido nem quebra)
    assert_equal "reviewed", @conversation.reload.triage.status
  end

  test "confirmar cliente existente persiste em campo próprio (não status)" do
    client = Client.create!(name: "ACME")
    patch conversation_triage_path(@conversation), params: { confirmed_client_id: client.id }
    d = @conversation.reload.triage
    assert_equal client.id, d.confirmed_client_id
    assert_equal "open", d.status # status NÃO vira "cliente"
  end

  test "id de cliente inexistente não confirma nada" do
    patch conversation_triage_path(@conversation), params: { confirmed_client_id: SecureRandom.uuid }
    assert_nil @conversation.reload.triage.confirmed_client_id
  end

  test "limpar cliente confirmado (vazio) remove confirmação e projeto" do
    client = Client.create!(name: "ACME")
    proj = client.projects.create!(name: "P", status: "planning")
    ConversationTriageDecision.create!(conversation: @conversation, confirmed_client: client, confirmed_project: proj)
    patch conversation_triage_path(@conversation), params: { confirmed_client_id: "" }
    d = @conversation.reload.triage
    assert_nil d.confirmed_client_id
    assert_nil d.confirmed_project_id
  end

  test "confirmar cliente NÃO cria task nem TimeEntry" do
    client = Client.create!(name: "ACME")
    assert_no_difference([ "Task.count", "TimeEntry.count", "ConversationLink.count" ]) do
      patch conversation_triage_path(@conversation), params: { confirmed_client_id: client.id }
    end
  end

  test "confirmação reflete no estado efetivo da Triagem (sobrepõe sugestão)" do
    client = Client.create!(name: "Confirmado ACME")
    patch conversation_triage_path(@conversation), params: { confirmed_client_id: client.id }
    r = ConversationTriage.derive(@conversation.reload)
    assert r.client_confirmed?
    assert_equal client.id, r.client.id
  end

  test "não altera conversations.personal (privacidade fora do workflow)" do
    @conversation.update!(personal: true)
    patch conversation_triage_path(@conversation), params: { status: "reviewed" }
    assert @conversation.reload.personal, "personal não deve ser tocado pela triagem"
  end
end
