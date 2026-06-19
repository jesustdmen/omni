require "test_helper"

# F5.3 (UI-10) — criar tarefa a partir da conversa + vínculo primary/manual atômico.
class ConversationTasksTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @conv = Conversation.create!(thread_id: "t-conv-1", source: "codex_session",
                                 title: "Planejamento X", personal: false, last_ts: Time.current)
  end

  test "usuário autenticado acessa new com título sugerido da conversa" do
    get new_conversation_task_path(@conv)
    assert_response :success
    assert_select "form[action=?]", conversation_tasks_path(@conv)
    assert_select "input[name=?][value=?]", "task[title]", "Planejamento X"
  end

  test "new sugere título fallback quando a conversa não tem título" do
    conv = Conversation.create!(thread_id: "cafebabe-xyz", source: "x", title: nil)
    get new_conversation_task_path(conv)
    assert_response :success
    assert_select "input[name=?][value=?]", "task[title]", "Conversa cafebabe"
  end

  test "POST create cria Task + ConversationLink primary/manual e vincula nos dois lados" do
    assert_difference -> { Task.count } => 1, -> { ConversationLink.count } => 1 do
      post conversation_tasks_path(@conv),
           params: { task: { client_id: @client.id, title: "Nova tarefa", type: "support", status: "todo" } }
    end
    task = Task.last
    link = ConversationLink.last
    assert_redirected_to task_path(task)

    assert_equal "primary", link.link_type
    assert_equal "manual", link.origin
    assert_equal @conv.id, link.conversation_id
    assert_equal task.id, link.task_id
    assert_equal @user.id, link.created_by_id

    # counters da task atualizados na mesma transação (after_create do link)
    assert_equal 1, task.reload.conversation_count

    # vínculo aparece na task...
    follow_redirect!
    assert_response :success
    assert_select "#tab-conversas", /Planejamento X/
    # ...e na conversa
    get conversation_path(@conv)
    assert_select "h2", /Vínculos/
    assert_select "td", /Nova tarefa/
  end

  test "conversa já com primary: new redireciona e create não cria nova task" do
    existing = @client.tasks.create!(title: "T0", type: "support")
    ConversationLink.create!(conversation: @conv, task: existing, link_type: "primary", origin: "manual")

    get new_conversation_task_path(@conv)
    assert_redirected_to conversation_path(@conv)
    assert_equal "Esta conversa já possui uma tarefa primária vinculada — remova o vínculo atual antes de criar outra.",
                 flash[:alert]

    assert_no_difference [ "Task.count", "ConversationLink.count" ] do
      post conversation_tasks_path(@conv),
           params: { task: { client_id: @client.id, title: "Outra", type: "support" } }
    end
    assert_redirected_to conversation_path(@conv)
  end

  test "task inválida não cria task nem link (rollback, sem órfã)" do
    assert_no_difference [ "Task.count", "ConversationLink.count" ] do
      post conversation_tasks_path(@conv), params: { task: { title: "", type: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "ação aparece na conversa sem primary e some quando há primary" do
    get conversation_path(@conv)
    assert_select "a[href=?]", new_conversation_task_path(@conv)

    t = @client.tasks.create!(title: "T", type: "support")
    ConversationLink.create!(conversation: @conv, task: t, link_type: "primary", origin: "manual")
    get conversation_path(@conv)
    assert_select "a[href=?]", new_conversation_task_path(@conv), count: 0
  end

  test "anônimo é redirecionado para login" do
    sign_out @user
    get new_conversation_task_path(@conv)
    assert_redirected_to new_user_session_path
    post conversation_tasks_path(@conv), params: { task: { client_id: @client.id, title: "X", type: "support" } }
    assert_redirected_to new_user_session_path
  end
end
