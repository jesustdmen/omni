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

  # --- F5.4 — lista acionável / status de vínculo ---

  test "conversa sem vínculo mostra 'Sem vínculo' e ação 'Criar tarefa'" do
    get conversations_path
    assert_response :success
    assert_select "td", /Sem vínculo/
    assert_select "a[href=?]", new_conversation_task_path(@beta), text: "Criar tarefa"
  end

  test "conversa com primary mostra badge linkando a task e oculta 'Criar tarefa'" do
    task = link_primary(@alpha, "Tarefa Alpha")
    get conversations_path
    assert_response :success
    assert_select "a.badge--info[href=?]", task_path(task), text: "Tarefa Alpha"
    assert_select "a[href=?]", new_conversation_task_path(@alpha), count: 0
  end

  test "conversa somente com menção mostra badge de menção" do
    t = task_for("Tarefa Menção")
    ConversationLink.create!(conversation: @alpha, task: t, link_type: "mention", origin: "manual")
    get conversations_path
    assert_response :success
    assert_select "td", /Menção \(1\)/
  end

  test "conversa com primary + menção mostra primária e '+N menção'" do
    primary_task = link_primary(@alpha, "Primária")
    ConversationLink.create!(conversation: @alpha, task: task_for("Outra"), link_type: "mention", origin: "manual")
    get conversations_path
    assert_response :success
    assert_select "a.badge--info[href=?]", task_path(primary_task)
    assert_select "span.muted", /\+1 menção/
  end

  test "filtro link=none retorna só conversas sem vínculo" do
    link_primary(@alpha, "T")
    get conversations_path(link: "none")
    assert_response :success
    assert_select "td", /t-beta-002/
    assert_select "td", { text: /Alpha conversa/, count: 0 }
  end

  test "filtro link=primary retorna só conversas com primária" do
    link_primary(@alpha, "T")
    get conversations_path(link: "primary")
    assert_response :success
    assert_select "td", /Alpha conversa/
    assert_select "td", { text: /t-beta-002/, count: 0 }
  end

  test "filtro link=mention inclui conversa com mention mesmo tendo primary" do
    link_primary(@alpha, "T")
    ConversationLink.create!(conversation: @alpha, task: task_for("M"), link_type: "mention", origin: "manual")
    get conversations_path(link: "mention")
    assert_response :success
    assert_select "td", /Alpha conversa/
    assert_select "td", { text: /t-beta-002/, count: 0 }
  end

  test "lista carrega vínculos em uma única query (eager load, sem N+1 por linha)" do
    # várias conversas vinculadas; com preload, conversation_links é carregado UMA vez
    # (IN ...), não uma query por linha. Robusto: independe de queries não relacionadas.
    link_primary(@alpha, "A")
    3.times do |i|
      conv = Conversation.create!(thread_id: "t-extra-#{i}", source: "codex_session",
                                  title: "Extra #{i}", last_ts: Time.current)
      ConversationLink.create!(conversation: conv, task: task_for("E#{i}"), link_type: "primary", origin: "manual")
    end

    link_queries = count_queries(/FROM "conversation_links"/) { get conversations_path }
    assert_response :success
    assert_equal 1, link_queries,
                 "vínculos devem ser carregados em 1 query (preload), não por conversa"
  end

  private

  def task_for(title)
    (@client ||= Client.create!(name: "ACME")).tasks.create!(title: title, type: "support")
  end

  def link_primary(conversation, task_title)
    task = task_for(task_title)
    ConversationLink.create!(conversation: conversation, task: task, link_type: "primary", origin: "manual")
    task
  end

  # Conta queries SQL cujo texto casa com `pattern` durante o bloco.
  def count_queries(pattern)
    count = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      sql = args.last[:sql].to_s
      count += 1 if pattern.match?(sql)
    end
    yield
    ActiveSupport::Notifications.unsubscribe(sub)
    count
  end
end
