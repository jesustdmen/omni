require "test_helper"

# PB-013 — busca global agrupada por categoria.
class GlobalSearchTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @client = Client.create!(name: "ACME LTDA", trade_name: "Acme", cnpj: "12345678000199")
  end

  test "exige autenticação" do
    sign_out @user
    get search_path(q: "acme")
    assert_redirected_to new_user_session_path
  end

  test "sem termo: mensagem de orientação" do
    get search_path
    assert_response :success
    assert_select ".empty", /Digite um termo/
  end

  test "termo sem resultados" do
    get search_path(q: "zzznadaaqui")
    assert_select ".empty", /Nenhum resultado/
  end

  # --- categorias ----------------------------------------------------------

  test "encontra tarefa por título com badge Tarefa e 'Encontrado em: Título'" do
    @client.tasks.create!(title: "Corrigir relatório financeiro", type: "support")
    get search_path(q: "relatório")
    assert_select ".search-group__title", /Tarefas/
    assert_select ".search-result__type", /Tarefa/
    assert_select ".search-result__title", /Corrigir relatório financeiro/
    assert_select ".search-result__matched", /Encontrado em: Título/
  end

  test "encontra tarefa pelo conteúdo do checklist (Encontrado em: Checklist)" do
    t = @client.tasks.create!(title: "Tarefa A", type: "support")
    t.checklist_items.create!(content: "comprar guarda-chuva xpto")
    get search_path(q: "xpto")
    assert_select ".search-result__title", /Tarefa A/
    assert_select ".search-result__matched", /Checklist/
  end

  test "encontra tarefa pela descrição do apontamento (Encontrado em: Apontamento)" do
    t = @client.tasks.create!(title: "Tarefa B", type: "support")
    now = Time.current
    t.time_entries.create!(start_time: now, end_time: now + 600, description: "reunião sobre kickoff zzqq")
    get search_path(q: "zzqq")
    assert_select ".search-result__title", /Tarefa B/
    assert_select ".search-result__matched", /Apontamento/
  end

  test "DISTINCT: tarefa que casa em título+checklist+apontamento aparece UMA vez com todos os campos" do
    t = @client.tasks.create!(title: "Projeto FOObar", description: "FOObar desc", type: "support")
    t.checklist_items.create!(content: "item FOObar")
    now = Time.current
    t.time_entries.create!(start_time: now, end_time: now + 600, description: "apontamento FOObar")
    get search_path(q: "foobar")
    # uma única linha de resultado de tarefa
    assert_select ".search-group", /Tarefas/ do
      assert_select ".search-result", 1
    end
    assert_select ".search-result__matched", /Título/
    assert_select ".search-result__matched", /Descrição/
    assert_select ".search-result__matched", /Checklist/
    assert_select ".search-result__matched", /Apontamento/
  end

  test "conversa: badge source + workspace; sem pesquisar turnos" do
    WorkspaceMap.create!(workspace_hash: "wshash01", folder: "c:/proj/viewer")
    Conversation.create!(thread_id: "t-1", source: "claude", title: "Refatorar exporter", last_ts: Time.current, workspace_hash: "wshash01")
    get search_path(q: "refatorar")
    assert_select ".search-group__title", /Conversas/
    assert_select ".search-result__type", /Conversa/
    assert_select ".search-result__context", /claude/i
    assert_select ".search-result__context", /viewer/
  end

  test "clientes: por nome e por CNPJ (com e sem pontuação)" do
    get search_path(q: "acme")
    assert_select ".search-group__title", /Clientes/
    assert_select ".search-result__title", /ACME LTDA/
    get search_path(q: "12.345.678/0001-99")
    assert_select ".search-result__matched", /CNPJ/
  end

  test "contatos: por e-mail; resultado leva ao cliente" do
    c = @client.contacts.create!(name: "João", email: "joao@acme.com")
    get search_path(q: "joao@acme")
    assert_select ".search-group__title", /Contatos/
    assert_select ".search-result__link[href^=?]", client_path(@client) # + return_to (PB-013b)
    assert_select ".search-result__matched", /E-mail/
  end

  test "projetos e demandas aparecem por nome/descrição" do
    @client.projects.create!(name: "Portal XYZ", status: "planning")
    Demand.create!(title: "Demanda XYZ", origin: "email", priority: "low", client: @client)
    get search_path(q: "XYZ")
    assert_select ".search-group__title", /Projetos/
    assert_select ".search-group__title", /Demandas/
  end

  # --- navegação dos resultados (card-link / Ir →) -------------------------

  test "cada resultado é um único link (card inteiro) com 'Ir →' e aria contextual" do
    t = @client.tasks.create!(title: "Corrigir relatório financeiro", type: "support")
    get search_path(q: "relatório")
    assert_select "a.search-result__link[href^=?]", task_path(t) do # + return_to (PB-013b)
      assert_select ".search-result__go", /Ir/
    end
    # PB-014 — o título do resultado (e o aria) incluem o código legível.
    assert_select "a.search-result__link[aria-label=?]", "Ir para tarefa #{t.code} — Corrigir relatório financeiro"
    # sem links aninhados dentro do card-link
    assert_select "a.search-result__link a", count: 0
  end

  test "ver todos aparece quando há mais que o limite por categoria" do
    6.times { |i| @client.tasks.create!(title: "Bug comum #{i}", type: "support") }
    get search_path(q: "Bug comum")
    assert_select ".search-group__more a[href=?]", tasks_path(q: "Bug comum")
  end

  # --- segurança da busca (escape) -----------------------------------------

  test "% e _ tratados como texto (não curinga)" do
    @client.tasks.create!(title: "desconto 50% promo", type: "support")
    @client.tasks.create!(title: "sem cifra", type: "support")
    get search_path(q: "50%")
    assert_select ".search-result__title", /50% promo/
    assert_select ".search-result__title", { text: /sem cifra/, count: 0 }
  end

  # --- voltar (PB-013) ------------------------------------------------------

  test "Voltar usa o referer interno (tela de onde busquei)" do
    get search_path(q: "acme"), headers: { "HTTP_REFERER" => "http://www.example.com/tasks?status=todo" }
    assert_select "a.back-link[href=?]", "/tasks?status=todo", /Voltar/
  end

  test "Voltar cai no Dashboard sem referer" do
    get search_path(q: "acme")
    assert_select "a.back-link[href=?]", root_path
  end

  test "Voltar ignora referer externo (outra origem) → Dashboard" do
    get search_path(q: "acme"), headers: { "HTTP_REFERER" => "https://evil.example.org/tasks" }
    assert_select "a.back-link[href=?]", root_path
  end

  test "Voltar não aponta para a própria busca (anti-loop) → Dashboard" do
    get search_path(q: "acme"), headers: { "HTTP_REFERER" => "http://www.example.com/search?q=outra" }
    assert_select "a.back-link[href=?]", root_path
  end

  # --- N+1 ------------------------------------------------------------------

  test "sem N+1 no workspace das conversas (mapa pré-carregado)" do
    WorkspaceMap.create!(workspace_hash: "wsA", folder: "c:/a")
    3.times { |i| Conversation.create!(thread_id: "tc#{i}", source: "claude", title: "Conv comum #{i}", last_ts: Time.current, workspace_hash: "wsA") }
    q = count_queries(/FROM "workspace_maps"/) { get search_path(q: "Conv comum") }
    assert_response :success
    assert q <= 1, "esperava ≤1 query em workspace_maps, obteve #{q}"
  end

  private

  def count_queries(pattern)
    count = 0
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      count += 1 if pattern.match?(args.last[:sql].to_s)
    end
    yield
    ActiveSupport::Notifications.unsubscribe(sub)
    count
  end
end
