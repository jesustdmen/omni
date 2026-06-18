require "test_helper"

class ConversationsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    WorkspaceMap.create!(workspace_hash: "wsR", folder: "c:/proj-resolvido")
    WorkspaceMap.create!(workspace_hash: "wsO", folder: nil)
    @alpha = Conversation.create!(thread_id: "t-alpha-001", source: "codex_session", title: "Alpha conversa",
                                  workspace_hash: "wsR", last_ts: Time.current, message_count: 3)
    @beta = Conversation.create!(thread_id: "t-beta-002", source: "agent_sessions", title: nil,
                                 workspace_hash: "wsO", last_ts: nil, message_count: 1)
  end

  test "exige autenticação" do
    sign_out @user
    get conversations_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza com KPIs e tabela" do
    get conversations_path
    assert_response :success
    assert_select "h1", "Conversas"
    assert_select ".metric-grid"
    assert_select "td", /Alpha conversa/
  end

  test "show renderiza metadados + seção de turnos read-only" do
    get conversation_path(@alpha)
    assert_response :success
    assert_select "dd", /t-alpha-001/
    assert_select "dd", /codex_session/
    assert_select "h2", "Conversa"
    # sem índice de turnos construído para esta conversa → aviso, sem render de conteúdo
    assert_match "Índice de turnos ainda não construído", response.body
    # nunca vaza caminho da fonte/shards na UI
    assert_no_match(/sessions\.jsonl|shards\//, response.body)
  end

  test "filtro por source" do
    get conversations_path(source: "codex_session")
    assert_response :success
    assert_select "td", /Alpha conversa/
    assert_select "td", { text: /agent_sessions/, count: 0 }
  end

  test "busca por thread_id" do
    get conversations_path(q: "t-beta")
    assert_response :success
    assert_select "td", /t-beta-002/
    assert_select "td", { text: /Alpha conversa/, count: 0 }
  end

  test "é somente leitura: sem rotas de escrita e sem controles destrutivos" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:new_conversation_path)
    assert_not helpers.respond_to?(:edit_conversation_path)

    get conversations_path
    # nenhum controle destrutivo de conversa (o único form post da página é o "Sair" da sidebar)
    assert_select "a[data-turbo-method=?]", "delete", count: 0
  end
end
