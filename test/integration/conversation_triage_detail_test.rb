require "test_helper"

# PB-020 (Triagem) — modo triagem da conversa em /conversations/:id?mode=triage.
# Somente leitura (exceto a decisão de triagem): tela dividida, evidências, cliente
# sugerido/confirmado, gaps visuais; ações existentes.
class ConversationTriageDetailTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
  end

  def conversation(**attrs)
    Conversation.create!({ thread_id: "t-#{SecureRandom.hex(4)}", message_count: 3,
                           user_turns: 1, assistant_turns: 1, tool_calls: 0 }.merge(attrs))
  end

  def turn_source
    @turn_source ||= TurnSource.create!(source_file: "/normalized/s.jsonl", source_label: "s.jsonl",
                                        content_hash: "h-#{SecureRandom.hex(4)}", schema_version: "v1",
                                        size_bytes: 100, source_mtime: Time.current, status: "ok")
  end

  def add_ref(conv, line_no, ts)
    ConversationTurnRef.create!(conversation: conv, turn_source: turn_source, thread_id: conv.thread_id,
                               line_no: line_no, byte_offset: line_no * 100, role: "user", ts: ts)
  end

  test "modo triagem renderiza o layout split sem quebrar" do
    c = conversation(title: "Conversa Triada", workspace_hash: "wh")
    WorkspaceMap.create!(workspace_hash: "wh", folder: "/erp/x")
    get conversation_path(c, mode: "triage")
    assert_response :success
    assert_select ".triage-detail"
    assert_select ".triage-detail__timeline"
    assert_select ".triage-detail__panel"
    assert_select "h2", text: "Evidências"
    # breadcrumb aponta para a Triagem
    assert_select "a[href=?]", triage_path, text: /Triagem/
  end

  test "show NORMAL (sem mode) segue intacto e não usa layout triagem" do
    c = conversation(title: "Conversa Normal")
    get conversation_path(c)
    assert_response :success
    assert_select ".triage-detail", count: 0
    assert_select "dt", text: "Thread" # metadados do show normal
    assert_select "a.back-link", text: "Voltar"
  end

  test "Voltar no detalhe retorna para a Triagem/filtro de origem (return_to)" do
    c = conversation(title: "Volta pro filtro")
    origin = triage_path(state: "noclient")
    get conversation_path(c, mode: "triage", return_to: origin)
    assert_response :success
    # o botão Voltar do painel aponta para o filtro de origem preservado
    assert_select ".triage-detail__cta a[href=?]", origin, text: "Voltar"
  end

  test "cliente sugerido é exibido como sugestão e agora há ação de confirmar (persistida)" do
    c = conversation(workspace_hash: "wh2")
    WorkspaceMap.create!(workspace_hash: "wh2", folder: "/erp/sara")
    Client.create!(name: "Sara Distribuidora", workspace_paths: [ "/erp/sara" ])
    get conversation_path(c, mode: "triage")
    assert_match "Sara Distribuidora", response.body
    assert_match(/sugerido pelo workspace/, response.body)
    # PB-020 persistida: agora EXISTE form para confirmar cliente (decisão humana).
    assert_select "form[action=?]", conversation_triage_path(c)
    assert_select "input[type=submit][value=?]", "Confirmar cliente"
  end

  test "gaps visuais aparecem (> 15 min) derivados dos timestamps" do
    c = conversation(title: "Com gap")
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    add_ref(c, 1, base)
    add_ref(c, 2, base + 40.minutes) # gap de 40 min
    get conversation_path(c, mode: "triage")
    assert_response :success
    assert_select ".triage-gaps__item"
    assert_match(/após turno 1/, response.body)
  end

  test "sem gaps relevantes mostra estado vazio (nada > 15 min)" do
    c = conversation(title: "Sem gap")
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    add_ref(c, 1, base)
    add_ref(c, 2, base + 5.minutes)
    get conversation_path(c, mode: "triage")
    assert_select ".triage-gaps__item", count: 0
    assert_match(/Nenhum gap relevante/, response.body)
  end

  test "NÃO mostra ação de classificar gap nesta fatia" do
    c = conversation
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    add_ref(c, 1, base)
    add_ref(c, 2, base + 30.minutes)
    get conversation_path(c, mode: "triage")
    assert_no_match(/Classificar/i, response.body)
    assert_select "button", text: /Classificar/i, count: 0
  end

  test "conversa pessoal mantém conteúdo dos turnos oculto" do
    c = conversation(title: "Pessoal", personal: true)
    get conversation_path(c, mode: "triage")
    assert_response :success
    assert_match(/pessoal/i, response.body)
    assert_match(/conteúdo dos turnos está oculto/i, response.body)
  end

  test "NÃO promove para TimeEntry nem grava apontamento (somente leitura)" do
    c = conversation(workspace_hash: "wh3")
    base = Time.utc(2026, 6, 10, 9, 0, 0)
    add_ref(c, 1, base); add_ref(c, 2, base + 30.minutes)
    assert_no_difference([ "TimeEntry.count", "ConversationLink.count", "Task.count", "ConversationTurnRef.count" ]) do
      get conversation_path(c, mode: "triage")
    end
    assert_no_match(/TimeEntry|Validar tempo|apontamento|promover/i, css_select("main.app-main").to_s)
  end

  test "CTAs reaproveitam fluxo existente: criar tarefa e vincular" do
    c = conversation(title: "Com CTA")
    get conversation_path(c, mode: "triage")
    assert_select "a[href*=?]", "/conversations/#{c.id}/tasks/new"
    # form de vínculo existente
    assert_select "form[action=?]", conversation_links_path(c)
  end

  # ── Ações por estado real do vínculo ──

  test "conversa NÃO vinculada mostra criar tarefa e vincular a existente" do
    c = conversation(title: "Sem tarefa")
    get conversation_path(c, mode: "triage")
    assert_select "a", text: "Criar tarefa desta conversa"
    assert_select "a", text: "Vincular a tarefa existente"
    assert_match(/ainda não tem tarefa primária/, response.body)
  end

  test "conversa VINCULADA mostra a tarefa e ação de abrir, sem oferecer criar do zero" do
    c = conversation(title: "Vinculada")
    task = Client.create!(name: "ACME").tasks.create!(title: "Tarefa T", type: "support")
    ConversationLink.create!(conversation: c, task: task, link_type: "primary", origin: "manual")
    get conversation_path(c, mode: "triage")
    assert_match(/Vinculada a/, response.body)
    assert_select "a[href=?]", task_path(task), text: "Abrir tarefa"
    assert_select "a", text: "Criar tarefa desta conversa", count: 0
  end

  test "cliente confirmado é levado ao criar tarefa (param client_id)" do
    c = conversation(title: "Com confirmado")
    client = Client.create!(name: "Confirmado ACME")
    ConversationTriageDecision.create!(conversation: c, status: "open", confirmed_client: client)
    get conversation_path(c, mode: "triage")
    assert_select "a[href=?]", new_conversation_task_path(c, client_id: client.id, return_to: conversation_path(c, mode: "triage"))
    assert_match(/cliente confirmado/, response.body)
  end

  test "cliente apenas sugerido NÃO vai como confirmado no criar tarefa" do
    c = conversation(workspace_hash: "wh-sug", title: "Só sugerido")
    WorkspaceMap.create!(workspace_hash: "wh-sug", folder: "/erp/sara")
    Client.create!(name: "Sugerida SA", workspace_paths: [ "/erp/sara" ])
    get conversation_path(c, mode: "triage")
    # o link de criar tarefa NÃO carrega client_id (sugestão não é confirmação)
    assert_select "a[href=?]", new_conversation_task_path(c, return_to: conversation_path(c, mode: "triage"))
    assert_match(/confirme acima para usá-lo/, response.body)
  end
end
