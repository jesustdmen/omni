require "test_helper"

class ConversationLinksTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "Bug X", type: "support")
    @conv = Conversation.create!(thread_id: "t-conv-1", source: "codex_session", title: "Conversa Alfa",
                                 last_ts: Time.current)
  end

  test "conversa exibe bloco de Vínculos" do
    get conversation_path(@conv)
    assert_response :success
    assert_select "h2", /Vínculos/
    assert_select "select[name=?]", "task_id"
    assert_select "select[name=?]", "link_type"
  end

  test "anônimo não pode vincular" do
    sign_out @user
    post conversation_links_path(@conv), params: { task_id: @task.id, link_type: "primary" }
    assert_redirected_to new_user_session_path
  end

  test "vincular conversa a tarefa manualmente (aparece nos dois lados)" do
    assert_difference "ConversationLink.count", 1 do
      post conversation_links_path(@conv), params: { task_id: @task.id, link_type: "primary" }
    end
    assert_redirected_to conversation_path(@conv)
    link = ConversationLink.last
    assert_equal "manual", link.origin
    assert_equal @user.id, link.created_by_id
    assert_equal 1, @task.reload.conversation_count

    # aparece em /conversations/:id
    get conversation_path(@conv)
    assert_select "td", /Bug X/
    # aparece em /tasks/:id (aba Conversas, read-only)
    get task_path(@task)
    assert_select "#tab-conversas td", /Conversa Alfa/
  end

  test "remover vínculo" do
    link = ConversationLink.create!(conversation: @conv, task: @task, link_type: "primary")
    assert_difference "ConversationLink.count", -1 do
      delete conversation_link_path(@conv, link)
    end
    assert_redirected_to conversation_path(@conv)
    assert_equal 0, @task.reload.conversation_count
  end

  test "mostra seção de conversa sem vazar caminho de sessions/shards" do
    get conversation_path(@conv)
    assert_select "h2", "Conversa"
    # conversa sem índice de turnos construído → aviso, sem render de conteúdo
    assert_match "Índice de turnos ainda não construído", response.body
    assert_no_match(/sessions\.jsonl|shards\//, response.body)
  end

  test "não há rotas de suggestions/scorer/auto-link" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:conversation_suggestions_path)
    assert_not helpers.respond_to?(:suggestions_path)
    assert_not helpers.respond_to?(:scorer_path)
    # links só create/destroy (sem index/edit/update)
    assert_not helpers.respond_to?(:edit_conversation_link_path)
  end
end
