require "test_helper"

# PB-020 (Triagem) — Inbox/Central de Triagem (read-only).
class TriageTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
  end

  def conversation(**attrs)
    Conversation.create!({ thread_id: "t-#{SecureRandom.hex(4)}", message_count: 3,
                           user_turns: 1, assistant_turns: 1, tool_calls: 0 }.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    get triage_path
    assert_redirected_to new_user_session_path
  end

  test "sidebar tem item Triagem (grupo Conversas)" do
    get root_path
    assert_select "a[href=?]", triage_path, text: /Triagem/
  end

  test "renderiza a central com cards por estado em PT-BR" do
    conversation(workspace_hash: nil) # noclient
    get triage_path
    assert_response :success
    assert_select "h1", "Central de Triagem"
    assert_select ".triage-card--pending"
    assert_select ".triage-card--noclient"
    assert_select ".triage-card--suggested"
    assert_select ".triage-card--linked"
    assert_match "Fila sem cliente", response.body
  end

  test "fila sem cliente lista conversa com workspace não resolvido" do
    conversation(workspace_hash: nil, title: "Sem dono aqui")
    get triage_path
    assert_match "Sem dono aqui", response.body
  end

  test "conversa pendente oferece Criar tarefa e Abrir/triar (reusa rotas existentes)" do
    c = conversation(workspace_hash: "h-pend", title: "Pendente X")
    WorkspaceMap.create!(workspace_hash: "h-pend", folder: "/sem/dono")
    get triage_path
    assert_select "a[href=?]", new_conversation_task_path(c, return_to: triage_path(state: nil))
    assert_select "a[href=?]", conversation_path(c, return_to: triage_path(state: nil))
  end

  test "filtro por estado restringe a fila principal" do
    conversation(workspace_hash: nil, title: "Conversa Sem Cliente")
    linked = conversation(workspace_hash: "h-link", title: "Conversa Vinculada")
    task = Client.create!(name: "ACME").tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: linked, task: task, link_type: "primary", origin: "manual")

    get triage_path(state: "linked")
    assert_match "Conversa Vinculada", response.body
    # a fila principal filtrada por 'linked' não mostra a sem-cliente
    assert_select ".triage-queue" do
      assert_select "a", text: /Conversa Sem Cliente/, count: 0
    end
  end

  test "conversa vinculada NÃO oferece Criar tarefa" do
    linked = conversation(workspace_hash: "h-l2", title: "Já vinculada")
    task = Client.create!(name: "ACME").tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: linked, task: task, link_type: "primary", origin: "manual")
    get triage_path(state: "linked")
    assert_select "a[href=?]", new_conversation_task_path(linked), count: 0
  end

  test "não promove nada para TimeEntry nem grava (read-only)" do
    conversation(workspace_hash: nil)
    assert_no_difference([ "TimeEntry.count", "ConversationLink.count", "Task.count" ]) do
      get triage_path
    end
    # a tela não tem nenhuma ação de criar/validar apontamento
    refute_match(/TimeEntry|Validar tempo|apontamento oficial/i, css_select("main.app-main").to_s)
  end
end
