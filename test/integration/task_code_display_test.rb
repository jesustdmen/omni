require "test_helper"

# PB-014 — exibição e busca do código legível de tarefa (TSK-000001).
class TaskCodeDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME LTDA", trade_name: "Acme", cnpj: "12345678000199")
    @task = @client.tasks.create!(title: "Corrigir relatório", type: "support")
  end

  # --- exibição --------------------------------------------------------------

  test "lista /tasks mostra o código junto ao título" do
    get tasks_path
    assert_response :success
    assert_select ".tasks-list__title", /#{Regexp.escape(@task.code)}/
    assert_select ".tasks-list__title", /Corrigir relatório/
  end

  test "detalhe /tasks/:id mostra o código no cabeçalho e nos detalhes" do
    get task_path(@task)
    assert_response :success
    assert_select ".badge-row .task-code", /#{Regexp.escape(@task.code)}/
    assert_select "dt", "Código"
    assert_select "dd", @task.code
  end

  test "busca global mostra o código no título do resultado" do
    get search_path(q: "relatório")
    assert_select ".search-result__title", /#{Regexp.escape(@task.code)}/
  end

  test "select de tarefa (vínculo da conversa) usa 'TSK-000001 — Título'" do
    conv = Conversation.create!(thread_id: "tc-1", source: "x", title: "C", last_ts: Time.current)
    get conversation_path(conv)
    assert_response :success
    assert_select "select[name=task_id] option", /#{Regexp.escape(@task.code)} — Corrigir relatório/
  end

  test "link de tarefa em apontamento exibe o código" do
    t = Time.current
    @task.time_entries.create!(start_time: t, end_time: t + 60)
    get time_entries_path
    assert_select "a", /#{Regexp.escape(@task.code)}/
  end

  test "demanda convertida: link 'Abrir TSK-...' exibe o código" do
    demand = Demand.create!(title: "D1", origin: "email", priority: "low", client: @client)
    res = ConvertDemand.call(demand)
    assert res.success?
    get demand_path(demand)
    assert_select "a", /Abrir #{Regexp.escape(res.task.code)}/
  end

  # --- criação propaga código ------------------------------------------------

  test "criação manual recebe código" do
    post tasks_path, params: { task: { client_id: @client.id, title: "Nova", type: "support", status: "todo" } }
    assert_response :redirect
    assert Task.order(:created_at).last.code_number.present?
  end

  test "conversa → tarefa recebe código" do
    conv = Conversation.create!(thread_id: "tc-2", source: "x", title: "C2", last_ts: Time.current)
    assert_difference "Task.count", 1 do
      post conversation_tasks_path(conv), params: { task: { client_id: @client.id, title: "Da conversa", type: "support" } }
    end
    assert Task.order(:created_at).last.code_number.present?
  end

  test "demanda → tarefa recebe código" do
    demand = Demand.create!(title: "D2", origin: "email", priority: "low", client: @client)
    res = ConvertDemand.call(demand)
    assert res.success?
    assert res.task.code_number.present?
  end

  # --- busca por código (lista e global) -------------------------------------

  test "busca da lista /tasks encontra por código completo (TSK-000001)" do
    other = @client.tasks.create!(title: "Outra coisa zzz", type: "support")
    get tasks_path(q: @task.code)
    assert_select ".tasks-list__title", /Corrigir relatório/
    assert_select ".tasks-list__title", { text: /Outra coisa zzz/, count: 0 }
  end

  test "busca da lista /tasks encontra por número e é case-insensitive" do
    get tasks_path(q: @task.code_number.to_s)
    assert_select ".tasks-list__title", /Corrigir relatório/
    get tasks_path(q: @task.code.downcase)
    assert_select ".tasks-list__title", /Corrigir relatório/
  end

  test "busca da lista mantém título/descrição e não quebra %/_ com termo-código" do
    @client.tasks.create!(title: "desconto 50% promo", type: "support")
    get tasks_path(q: "50%")
    assert_select ".tasks-list__title", /50% promo/
  end

  test "busca global encontra tarefa por código (Encontrado em: Código)" do
    get search_path(q: @task.code)
    assert_select ".search-result__title", /#{Regexp.escape(@task.code)}/
    assert_select ".search-result__matched", /Código/
  end

  test "busca global por número também casa o código" do
    get search_path(q: @task.code_number.to_s)
    assert_select ".search-result__title", /Corrigir relatório/
  end

  # --- segurança: código não atribuível por parâmetro ------------------------

  test "code_number enviado por params é ignorado na criação" do
    post tasks_path, params: { task: { client_id: @client.id, title: "X", type: "support", status: "todo", code_number: 999_999 } }
    created = Task.order(:created_at).last
    assert_not_equal 999_999, created.code_number, "code_number não pode ser definido por parâmetro"
  end
end
