require "test_helper"

# PB-004a — lista operacional de /tasks: busca, filtros, paginação, ações e vazios.
class TasksListTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @acme = Client.create!(name: "ACME")
    @globex = Client.create!(name: "Globex")
  end

  def task(attrs = {})
    base = { client: @acme, title: "Tarefa", type: "support", status: "todo" }
    Task.create!(base.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    get tasks_path
    assert_redirected_to new_user_session_path
  end

  # --- busca ---------------------------------------------------------------

  test "busca por título" do
    task(title: "Corrigir relatório financeiro")
    task(title: "Outra coisa")
    get tasks_path(q: "relatório")
    assert_response :success
    assert_select "td.tasks-list__title", /Corrigir relatório/
    assert_select "td.tasks-list__title", { text: /Outra coisa/, count: 0 }
  end

  test "busca por descrição" do
    task(title: "T1", description: "contém a palavra mágica xyzzy")
    task(title: "T2", description: "nada aqui")
    get tasks_path(q: "xyzzy")
    assert_select "td.tasks-list__title", /T1/
    assert_select "td.tasks-list__title", { text: /T2/, count: 0 }
  end

  test "busca é case-insensitive" do
    task(title: "Banco de Dados")
    get tasks_path(q: "banco")
    assert_select "td.tasks-list__title", /Banco de Dados/
  end

  test "caractere % é tratado como texto, não curinga" do
    match = task(title: "desconto 50% aplicado")
    noise = task(title: "sem cifra")
    get tasks_path(q: "50%")
    assert_select "td.tasks-list__title", /50% aplicado/
    assert_select "td.tasks-list__title", { text: /sem cifra/, count: 0 }, "% não pode virar curinga (casaria tudo)"
  end

  test "caractere _ é tratado como texto, não curinga" do
    task(title: "arquivo_final")
    task(title: "arquivoXfinal")
    get tasks_path(q: "arquivo_final")
    assert_select "td.tasks-list__title", /arquivo_final/
    assert_select "td.tasks-list__title", { text: /arquivoXfinal/, count: 0 }, "_ não pode casar qualquer caractere"
  end

  # --- filtros -------------------------------------------------------------

  test "filtro por status" do
    task(title: "Aberta", status: "todo")
    task(title: "Fechada", status: "done")
    get tasks_path(status: "done")
    assert_select "td.tasks-list__title", /Fechada/
    assert_select "td.tasks-list__title", { text: /Aberta/, count: 0 }
  end

  test "filtro por tipo" do
    task(title: "Suporte", type: "support")
    task(title: "Dev", type: "development")
    get tasks_path(type: "development")
    assert_select "td.tasks-list__title", /Dev/
    assert_select "td.tasks-list__title", { text: /Suporte/, count: 0 }
  end

  test "filtro por cliente" do
    task(title: "Da ACME", client: @acme)
    task(title: "Da Globex", client: @globex)
    get tasks_path(client_id: @globex.id)
    assert_select "td.tasks-list__title", /Da Globex/
    assert_select "td.tasks-list__title", { text: /Da ACME/, count: 0 }
  end

  test "combinação de busca + filtros" do
    task(title: "Bug no login", type: "support", client: @acme, status: "todo")
    task(title: "Bug no login", type: "development", client: @acme, status: "todo") # tipo diferente
    task(title: "Bug no checkout", type: "support", client: @acme, status: "todo")  # título diferente
    get tasks_path(q: "login", type: "support", client_id: @acme.id, status: "todo")
    assert_select "tbody tr", 1
    assert_select "td.tasks-list__title", /Bug no login/
  end

  # --- parâmetros inválidos (comportamento seguro) -------------------------

  test "status inválido é ignorado (não filtra)" do
    task(title: "A")
    task(title: "B")
    get tasks_path(status: "inexistente")
    assert_select "tbody tr", 2
  end

  test "tipo inválido é ignorado" do
    task(title: "A")
    task(title: "B")
    get tasks_path(type: "xxx")
    assert_select "tbody tr", 2
  end

  test "client_id inválido é ignorado" do
    task(title: "A")
    get tasks_path(client_id: "00000000-0000-0000-0000-000000000000")
    assert_select "tbody tr", 1
  end

  # --- paginação -----------------------------------------------------------

  test "per_page limita resultados e default é 50" do
    12.times { |i| task(title: "T#{format('%02d', i)}") }
    get tasks_path(per_page: 10)
    assert_select "tbody tr", 10
    assert_select ".pagination", /12 tarefa\(s\)/
    assert_select ".pagination", /página 1\/2/
  end

  test "per_page inválido cai no default (50)" do
    3.times { |i| task(title: "T#{i}") }
    get tasks_path(per_page: 999)
    assert_response :success
    assert_select "tbody tr", 3 # 3 < 50 default
  end

  test "página inválida/negativa volta para a primeira" do
    12.times { |i| task(title: "T#{i}") }
    get tasks_path(per_page: 10, page: -5)
    assert_select ".pagination", /página 1\//
    get tasks_path(per_page: 10, page: 999)
    assert_select ".pagination", /página 1\//
  end

  test "ordenação estável: created_at desc, id desc" do
    a = task(title: "Primeira")
    b = task(title: "Segunda")
    get tasks_path
    titles = css_select("td.tasks-list__title a").map(&:text)
    assert_equal [ "Segunda", "Primeira" ], titles.first(2)
    assert b.created_at >= a.created_at
  end

  test "links de paginação preservam busca, filtros e per_page" do
    15.times { task(title: "Bug login", type: "support", client: @acme) }
    get tasks_path(q: "Bug", type: "support", client_id: @acme.id, per_page: 10)
    assert_select "a", text: /Próxima/ do |els|
      href = els.first["href"]
      assert_match(/q=Bug/, href)
      assert_match(/type=support/, href)
      assert_match(/client_id=#{@acme.id}/, href)
      assert_match(/per_page=10/, href)
      assert_match(/page=2/, href)
    end
  end

  # --- tabela / ações ------------------------------------------------------

  test "tabela mostra colunas e ações Ver/Editar/Excluir" do
    t = task(title: "Com ações", description: "uma descrição qualquer")
    get tasks_path
    assert_select "td.tasks-list__title", /Com ações/
    assert_select "td.tasks-list__title .tasks-list__excerpt", /uma descrição/
    assert_select ".te-actions a[href^=?]", task_path(t)            # Ver (+ return_to, PB-013b)
    assert_select ".te-actions a[href^=?]", edit_task_path(t)       # Editar (+ return_to)
    assert_select ".te-actions form[action=?][method=post]", task_path(t) do
      assert_select "input[name=_method][value=delete]", true      # Excluir (DELETE)
      assert_select "input[name=return_to]", true                  # PB-013b — contexto
    end
  end

  test "Nova tarefa permanece destacada (btn--primary)" do
    get tasks_path
    assert_select "a.btn--primary[href=?]", new_task_path, /Nova tarefa/
  end

  # --- estados vazios ------------------------------------------------------

  test "estado vazio: nenhuma tarefa cadastrada" do
    get tasks_path
    assert_select ".empty", /Nenhuma tarefa cadastrada/
    assert_select ".empty a.btn--primary[href=?]", new_task_path
  end

  test "estado vazio: nenhum resultado para filtros oferece Limpar filtros" do
    task(title: "existe")
    get tasks_path(q: "naoexistenada")
    assert_select ".empty", /Nenhuma tarefa para os filtros atuais/
    assert_select ".empty a[href=?]", tasks_path, /Limpar filtros/
  end

  # --- integridade ---------------------------------------------------------

  test "sem N+1: carrega tasks da página em consulta única (independe da quantidade)" do
    10.times { |i| task(title: "T#{i}", project: nil) }
    q = count_queries(/FROM "tasks"/) { get tasks_path(per_page: 50) }
    assert_response :success
    # 1 count (total) + 1 select da página = 2; não cresce por linha.
    assert q <= 2, "esperava ≤2 queries em tasks, obteve #{q}"
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
