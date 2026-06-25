require "test_helper"

# PB-020 (Triagem) — estado efetivo de conversas (derivado + decisão persistida).
class ConversationTriageTest < ActiveSupport::TestCase
  def conversation(**attrs)
    Conversation.create!({ thread_id: "t-#{SecureRandom.hex(4)}", message_count: 3,
                           user_turns: 1, assistant_turns: 1, tool_calls: 0 }.merge(attrs))
  end

  test "linked: conversa com vínculo a tarefa" do
    c = conversation
    client = Client.create!(name: "ACME")
    task = client.tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: c, task: task, link_type: "primary", origin: "manual")
    assert_equal "linked", ConversationTriage.derive(c).state
  end

  test "personal: conversa marcada como pessoal (sem vínculo)" do
    c = conversation(personal: true)
    assert_equal "personal", ConversationTriage.derive(c).state
  end

  test "noclient: sem vínculo e workspace não resolvido" do
    c = conversation(workspace_hash: "hash-sem-mapa")
    r = ConversationTriage.derive(c)
    assert_equal "noclient", r.state
    assert_nil r.client
  end

  test "noclient também quando workspace_hash é nil" do
    c = conversation(workspace_hash: nil)
    assert_equal "noclient", ConversationTriage.derive(c).state
  end

  test "pending: workspace resolvido mas sem cliente casado" do
    c = conversation(workspace_hash: "hash-x")
    WorkspaceMap.create!(workspace_hash: "hash-x", folder: "/work/projeto-sem-dono")
    assert_equal "pending", ConversationTriage.derive(c).state
  end

  test "suggested: workspace resolvido casa com Client.workspace_paths" do
    c = conversation(workspace_hash: "hash-sara")
    WorkspaceMap.create!(workspace_hash: "hash-sara", folder: "/erp/sara")
    client = Client.create!(name: "Sara Distribuidora", workspace_paths: [ "/erp/sara" ])
    r = ConversationTriage.derive(c)
    assert_equal "suggested", r.state
    assert_equal client.id, r.client.id
    assert_not r.client_confirmed?
  end

  test "suggestion casa de forma tolerante (caixa/barra/barra final)" do
    c = conversation(workspace_hash: "hash-y")
    WorkspaceMap.create!(workspace_hash: "hash-y", folder: "C:\\Work\\Cliente\\")
    client = Client.create!(name: "Cliente", workspace_paths: [ "c:/work/cliente" ])
    assert_equal client.id, ConversationTriage.derive(c).client&.id
  end

  test "linked tem prioridade sobre suggested/personal" do
    c = conversation(workspace_hash: "hash-z", personal: true)
    WorkspaceMap.create!(workspace_hash: "hash-z", folder: "/p")
    Client.create!(name: "C", workspace_paths: [ "/p" ])
    task = Client.create!(name: "Dono").tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: c, task: task, link_type: "primary", origin: "manual")
    assert_equal "linked", ConversationTriage.derive(c).state
  end

  test "index_for não faz N+1 e cobre a coleção" do
    c1 = conversation(workspace_hash: "h1")
    c2 = conversation(workspace_hash: nil)
    WorkspaceMap.create!(workspace_hash: "h1", folder: "/erp/x")
    Client.create!(name: "X", workspace_paths: [ "/erp/x" ])
    idx = ConversationTriage.index_for([ c1, c2 ])
    assert_equal "suggested", idx[c1.id].state
    assert_equal "noclient", idx[c2.id].state
  end

  test "é somente leitura: não grava nada" do
    c = conversation(workspace_hash: "h")
    assert_no_difference([ "Conversation.count", "ConversationLink.count", "Task.count", "TimeEntry.count" ]) do
      ConversationTriage.index_for([ c ])
    end
  end

  # ── PB-020 persistida mínima: estado efetivo (decisão humana sobrepõe o derivado) ──

  test "sem decisão persistida, mantém o estado derivado (compat)" do
    c = conversation(workspace_hash: nil)
    r = ConversationTriage.derive(c)
    assert_equal "noclient", r.state
    assert_not r.persisted?
  end

  test "status persistido reviewed sobrepõe o fluxo derivado" do
    c = conversation(workspace_hash: nil) # derivado seria noclient
    ConversationTriageDecision.create!(conversation: c, status: "reviewed")
    r = ConversationTriage.derive(c)
    assert_equal "reviewed", r.state
    assert_equal "reviewed", r.persisted_status
    assert r.persisted?
  end

  test "status persistido ignored sobrepõe o derivado" do
    c = conversation(workspace_hash: nil)
    ConversationTriageDecision.create!(conversation: c, status: "ignored")
    assert_equal "ignored", ConversationTriage.derive(c).state
  end

  test "cliente confirmado prevalece sobre sugestão de workspace" do
    c = conversation(workspace_hash: "h-sara")
    WorkspaceMap.create!(workspace_hash: "h-sara", folder: "/erp/sara")
    sugerido = Client.create!(name: "Sugerido", workspace_paths: [ "/erp/sara" ])
    confirmado = Client.create!(name: "Confirmado")
    ConversationTriageDecision.create!(conversation: c, status: "open", confirmed_client: confirmado)
    r = ConversationTriage.derive(c)
    assert_equal confirmado.id, r.client.id
    assert r.client_confirmed?
    assert_not_equal sugerido.id, r.client.id
    assert_equal "suggested", r.state # tem cliente efetivo
  end

  test "linked permanece derivado mesmo com decisão reviewed" do
    c = conversation
    task = Client.create!(name: "ACME").tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: c, task: task, link_type: "primary", origin: "manual")
    ConversationTriageDecision.create!(conversation: c, status: "reviewed")
    assert_equal "linked", ConversationTriage.derive(c).state # linked tem prioridade
  end

  test "personal permanece derivado mesmo com decisão reviewed" do
    c = conversation(personal: true)
    ConversationTriageDecision.create!(conversation: c, status: "reviewed")
    assert_equal "personal", ConversationTriage.derive(c).state
  end

  test "index_for aplica a decisão persistida (estado efetivo) sem N+1" do
    c1 = conversation(workspace_hash: nil)
    c2 = conversation(workspace_hash: nil)
    ConversationTriageDecision.create!(conversation: c2, status: "ignored")
    idx = ConversationTriage.index_for([ c1, c2 ])
    assert_equal "noclient", idx[c1.id].state
    assert_equal "ignored", idx[c2.id].state
  end
end
