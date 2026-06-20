require "test_helper"

class TasksTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
    @project = @client.projects.create!(name: "Portal")
  end

  test "exige autenticação" do
    sign_out @user
    get tasks_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    @client.tasks.create!(title: "Bug X", type: "support")
    get tasks_path
    assert_response :success
    assert_select "h1", "Tarefas"
    assert_select "td", /Bug X/
  end

  test "new renderiza formulário com selects" do
    get new_task_path
    assert_response :success
    assert_select "form"
    assert_select "select[name=?]", "task[client_id]"
    assert_select "select[name=?]", "task[project_id]"
    assert_select "select[name=?]", "task[type]"
    assert_select "select[name=?]", "task[status]"
  end

  test "create válido redireciona" do
    assert_difference "Task.count", 1 do
      post tasks_path, params: { task: { client_id: @client.id, title: "Bug X", type: "support", status: "todo" } }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "Task.count" do
      post tasks_path, params: { task: { client_id: @client.id, title: "", type: "support" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "show /tasks/:id mostra dados e abas" do
    task = @client.tasks.create!(title: "Bug X", type: "support", project: @project)
    get task_path(task)
    assert_response :success
    assert_select "h1", "Bug X"
    assert_select "dd", /ACME/
    assert_select "dd", /Portal/
    assert_select ".tab", /Detalhes/
    assert_select ".tab", /Conversas/
    assert_select ".tab", /Time entries/
    assert_select ".tab", /Histórico/
    assert_select ".tab", /Demanda/
  end

  # F5.5 — navegação honesta por âncoras (sem JS).
  test "abas reais são links de âncora; 'em breve' não têm href" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    get task_path(task)
    assert_response :success
    assert_select "a.tab[href=?]", "#tab-detalhes", /Detalhes/
    assert_select "a.tab[href=?]", "#tab-conversas", /Conversas/
    assert_select "a.tab[href=?]", "#tab-time", /Time entries/
    # Histórico/Demanda continuam como itens "em breve" sem href (não-link).
    assert_select "span.tab.soon", /Histórico/
    assert_select "span.tab.soon", /Demanda/
    assert_select "a.tab", { text: /Histórico/, count: 0 }
    assert_select "a.tab", { text: /Demanda/, count: 0 }
  end

  test "aba Conversas mostra contagem quando há vínculos e não mostra sem vínculo" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    get task_path(task)
    assert_select "a.tab[href=?]", "#tab-conversas" do |els|
      assert_no_match(/\(\d+\)/, els.text)
    end

    conv = Conversation.create!(thread_id: "t-c1", source: "x", title: "C1", last_ts: Time.current)
    ConversationLink.create!(conversation: conv, task: task, link_type: "primary", origin: "manual")
    get task_path(task)
    assert_select "a.tab[href=?]", "#tab-conversas", /Conversas\s*\(1\)/
    assert_select "#tab-conversas", /C1/
  end

  test "aba Time entries mostra lista read-only e total de duração" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 12)
    get task_path(task)
    assert_response :success
    assert_select "#tab-time table"
    assert_select "#tab-time", /Histórico de Apontamentos/
    assert_select "#tab-time", /apontamento\(s\) registrado\(s\)/
    assert_select "#tab-time", /Total de duração/
    assert_select "#tab-time", /42/
  end

  # PB-003b — agrupamento por dia: cada grupo validado isoladamente, ordem
  # intradiária decrescente e timer em andamento no grupo correto (fora do subtotal).
  test "histórico agrupa por dia: grupos isolados, ordem intradiária e timer no dia certo" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    hoje = Date.current
    ontem = hoje - 1
    h09   = Time.zone.local(hoje.year, hoje.month, hoje.day, 9, 0)
    h1430 = Time.zone.local(hoje.year, hoje.month, hoje.day, 14, 30)
    h16   = Time.zone.local(hoje.year, hoje.month, hoje.day, 16, 0)
    o10   = Time.zone.local(ontem.year, ontem.month, ontem.day, 10, 0)

    task.time_entries.create!(start_time: h09,   date: hoje,  duration: 600)   # 10 min
    task.time_entries.create!(start_time: h1430, date: hoje,  duration: 1800)  # 30 min
    task.time_entries.create!(start_time: h16,   date: hoje,  is_running: true, duration: 0) # 16:00 em andamento
    task.time_entries.create!(start_time: o10,   date: ontem, duration: 300)   # 5 min (dia anterior)

    get task_path(task)
    assert_response :success

    groups = css_select("#tab-time tbody.te-day")
    assert_equal 2, groups.size, "deve haver exatamente um grupo por dia"

    hoje_str  = hoje.strftime("%d/%m/%Y")
    ontem_str = ontem.strftime("%d/%m/%Y")

    # --- Grupo 1: data MAIS RECENTE (hoje), validado isoladamente ---
    g0 = groups[0]
    assert_match hoje_str, g0.at_css(".te-day__head").text
    assert_no_match(/#{Regexp.escape(ontem_str)}/, g0.text, "grupo 1 não deve conter a data anterior")
    # subtotal do grupo 1 = só as entradas de hoje, running excluído: 10+30 = 40 min
    assert_match(/Subtotal do dia/, g0.at_css(".te-day__subtotal").text)
    assert_match(/40 min/, g0.at_css(".te-day__subtotal").text)
    assert_no_match(/5 min/, g0.at_css(".te-day__subtotal").text, "subtotal de hoje não inclui o dia anterior")
    # timer em andamento visível NO grupo de hoje
    assert_match(/em andamento/, g0.text)
    assert_match("16:00", g0.text)
    # ordem intradiária decrescente por horário (Início = 2ª célula das linhas de apontamento)
    assert_equal %w[16:00 14:30 09:00], entry_start_times(g0)

    # --- Grupo 2: data ANTERIOR (ontem), validado isoladamente ---
    g1 = groups[1]
    assert_match ontem_str, g1.at_css(".te-day__head").text
    assert_no_match(/#{Regexp.escape(hoje_str)}/, g1.text, "grupo 2 não deve conter a data de hoje")
    # subtotal do grupo 2 = só o dia anterior: 5 min
    assert_match(/5 min/, g1.at_css(".te-day__subtotal").text)
    assert_no_match(/40 min/, g1.at_css(".te-day__subtotal").text, "subtotal de ontem não inclui hoje")
    # timer em andamento NÃO está no grupo de ontem
    assert_no_match(/em andamento/, g1.text)
    assert_equal %w[10:00], entry_start_times(g1)

    # total geral (running=0): 40 + 5 = 45 min
    assert_select "#tab-time .te-total", /45 min/
  end

  # PB-003a — ações operacionais diretas na linha do histórico.
  test "linha do apontamento expõe Editar e Excluir diretamente" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    entry = task.time_entries.create!(start_time: Time.current, date: Date.current, duration: 30)
    get task_path(task)
    assert_response :success
    assert_select "#tab-time .te-actions a[href=?]", edit_time_entry_path(entry)
    assert_select "#tab-time .te-actions form[action=?][method=post]", time_entry_path(entry) do
      assert_select "input[name=_method][value=delete]", true
    end
    # sem timer aberto → sem botão "Parar" na linha
    assert_select "#tab-time .te-actions form[action=?]", stop_time_entry_path(entry), count: 0
  end

  test "linha do timer em andamento expõe Parar diretamente" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    running = task.time_entries.create!(start_time: Time.current, date: Date.current, is_running: true, duration: 0)
    get task_path(task)
    assert_response :success
    assert_select "#tab-time .te-actions form[action=?]", stop_time_entry_path(running)
    assert_select "#tab-time .te-actions a[href=?]", edit_time_entry_path(running)
  end

  test "edit e update" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    get edit_task_path(task)
    assert_response :success
    patch task_path(task), params: { task: { title: "Bug Y" } }
    assert_redirected_to task_path(task)
    assert_equal "Bug Y", task.reload.title
  end

  test "destroy" do
    task = @client.tasks.create!(title: "Bug X", type: "support")
    assert_difference "Task.count", -1 do
      delete task_path(task)
    end
    assert_redirected_to tasks_path
  end

  private

  # PB-003b — horários de Início (2ª célula) das linhas de apontamento de um grupo
  # `tbody.te-day`, em ordem de documento (ignora cabeçalho de data e linha de subtotal).
  def entry_start_times(group)
    group.css("tr").select { |tr| tr.at_css("td.te-desc") }.map { |tr| tr.css("td")[1].text.strip }
  end
end
