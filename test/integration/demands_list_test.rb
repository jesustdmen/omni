require "test_helper"

# PB-005 — lista operacional de /demands: busca, filtros, paginação, ações, conversão.
class DemandsListTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @acme = Client.create!(name: "ACME")
    @globex = Client.create!(name: "Globex")
  end

  def demand(attrs = {})
    base = { title: "Demanda", origin: "email", priority: "medium", status: "pending", client: @acme }
    Demand.create!(base.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    get demands_path
    assert_redirected_to new_user_session_path
  end

  # --- busca ---------------------------------------------------------------

  test "busca por título" do
    demand(title: "Bug no relatório")
    demand(title: "Outra coisa")
    get demands_path(q: "relatório")
    assert_select "td.demands-list__title", /Bug no relatório/
    assert_select "td.demands-list__title", { text: /Outra coisa/, count: 0 }
  end

  test "busca por descrição" do
    demand(title: "D1", description: "contém xyzzy aqui")
    demand(title: "D2", description: "nada")
    get demands_path(q: "xyzzy")
    assert_select "td.demands-list__title", /D1/
    assert_select "td.demands-list__title", { text: /D2/, count: 0 }
  end

  test "busca por observações" do
    demand(title: "D1", observations: "nota interna zzqq")
    demand(title: "D2", observations: "outra")
    get demands_path(q: "zzqq")
    assert_select "td.demands-list__title", /D1/
    assert_select "td.demands-list__title", { text: /D2/, count: 0 }
  end

  test "busca case-insensitive" do
    demand(title: "Fechamento Contábil")
    get demands_path(q: "contábil")
    assert_select "td.demands-list__title", /Fechamento Contábil/
  end

  test "% é tratado como texto, não curinga" do
    demand(title: "desconto 50% extra")
    demand(title: "sem cifra")
    get demands_path(q: "50%")
    assert_select "td.demands-list__title", /50% extra/
    assert_select "td.demands-list__title", { text: /sem cifra/, count: 0 }
  end

  test "_ é tratado como texto, não curinga" do
    demand(title: "arquivo_final")
    demand(title: "arquivoXfinal")
    get demands_path(q: "arquivo_final")
    assert_select "td.demands-list__title", /arquivo_final/
    assert_select "td.demands-list__title", { text: /arquivoXfinal/, count: 0 }
  end

  # --- filtros -------------------------------------------------------------

  test "filtro por prioridade" do
    demand(title: "Alta", priority: "high")
    demand(title: "Baixa", priority: "low")
    get demands_path(priority: "high")
    assert_select "td.demands-list__title", /Alta/
    assert_select "td.demands-list__title", { text: /Baixa/, count: 0 }
  end

  test "filtro por origem" do
    demand(title: "Por telefone", origin: "phone")
    demand(title: "Por email", origin: "email")
    get demands_path(origin: "phone")
    assert_select "td.demands-list__title", /Por telefone/
    assert_select "td.demands-list__title", { text: /Por email/, count: 0 }
  end

  test "filtro por status" do
    pend = demand(title: "Pendente")
    conv = demand(title: "Convertida")
    ConvertDemand.call(conv)
    get demands_path(status: "converted")
    assert_select "td.demands-list__title", /Convertida/
    assert_select "td.demands-list__title", { text: /Pendente/, count: 0 }
  end

  test "filtro por cliente" do
    demand(title: "Da ACME", client: @acme)
    demand(title: "Da Globex", client: @globex)
    get demands_path(client_id: @globex.id)
    assert_select "td.demands-list__title", /Da Globex/
    assert_select "td.demands-list__title", { text: /Da ACME/, count: 0 }
  end

  test "combinação busca + filtros" do
    demand(title: "Bug fiscal", priority: "high", origin: "phone", client: @acme)
    demand(title: "Bug fiscal", priority: "low",  origin: "phone", client: @acme)  # prioridade difere
    demand(title: "Bug contábil", priority: "high", origin: "phone", client: @acme) # título difere
    get demands_path(q: "fiscal", priority: "high", origin: "phone", client_id: @acme.id)
    assert_select "tbody tr", 1
    assert_select "td.demands-list__title", /Bug fiscal/
  end

  # --- parâmetros inválidos ------------------------------------------------

  test "parâmetros inválidos são ignorados com segurança" do
    demand(title: "A"); demand(title: "B")
    get demands_path(priority: "xxx", origin: "yyy", status: "zzz", client_id: "00000000-0000-0000-0000-000000000000")
    assert_select "tbody tr", 2
  end

  # --- paginação -----------------------------------------------------------

  test "per_page limita e default é 50; página inválida volta para 1" do
    12.times { |i| demand(title: "D#{format('%02d', i)}") }
    get demands_path(per_page: 10)
    assert_select "tbody tr", 10
    assert_select ".pagination", /12 demanda\(s\)/
    assert_select ".pagination__status", /Página 1 de 2/
    get demands_path(per_page: 10, page: 999)
    assert_select ".pagination__status", /Página 1 de/
  end

  test "links de paginação preservam busca/filtros/per_page" do
    15.times { demand(title: "Bug fiscal", priority: "high", client: @acme) }
    get demands_path(q: "Bug", priority: "high", client_id: @acme.id, per_page: 10)
    assert_select "a", text: /Próxima/ do |els|
      href = els.first["href"]
      assert_match(/q=Bug/, href)
      assert_match(/priority=high/, href)
      assert_match(/client_id=#{@acme.id}/, href)
      assert_match(/per_page=10/, href)
      assert_match(/page=2/, href)
    end
  end

  # --- ações / conversão pela lista ----------------------------------------

  test "pending com cliente mostra Converter" do
    d = demand(title: "Convertível", client: @acme)
    get demands_path
    assert_select ".te-actions form[action=?]", convert_demand_path(d)
  end

  test "pending SEM cliente não aparece convertível (indicação clara)" do
    d = demand(title: "Sem cliente", client: nil)
    get demands_path
    assert_select ".te-actions form[action=?]", convert_demand_path(d), count: 0
    assert_select "td .demands-list__no-client", /sem cliente/
  end

  test "converted mostra link para a tarefa e não oferece nova conversão" do
    d = demand(title: "Já convertida")
    task = ConvertDemand.call(d).task
    get demands_path
    assert_select ".te-actions a[href=?]", task_path(task), /Abrir #{Regexp.escape(task.code)}/ # PB-014
    assert_select ".te-actions form[action=?]", convert_demand_path(d), count: 0
  end

  test "converter pela lista cria a tarefa vinculada" do
    d = demand(title: "Converter agora", client: @acme)
    assert_difference "Task.count", 1 do
      post convert_demand_path(d)
    end
    assert_equal d.id, Task.order(:created_at).last.demand_id
  end

  test "segunda conversão bloqueada (sem 2ª tarefa)" do
    d = demand(title: "Dupla")
    ConvertDemand.call(d)
    assert_no_difference "Task.count" do
      post convert_demand_path(d.reload)
    end
  end

  test "ações Ver/Editar/Excluir presentes" do
    d = demand(title: "Com ações", description: "uma descrição")
    get demands_path
    assert_select "td.demands-list__title .demands-list__excerpt", /uma descrição/
    assert_select ".te-actions a[href^=?]", demand_path(d)        # Ver (+ return_to, PB-013b)
    assert_select ".te-actions a[href^=?]", edit_demand_path(d)   # Editar (+ return_to)
    assert_select ".te-actions form[action=?][method=post]", demand_path(d) do
      assert_select "input[name=_method][value=delete]", true    # Excluir
      assert_select "input[name=return_to]", true                # PB-013b — contexto
    end
  end

  test "Nova demanda permanece destacada" do
    get demands_path
    assert_select "a.btn--primary[href=?]", new_demand_path, /Nova demanda/
  end

  # --- estados vazios ------------------------------------------------------

  test "estado vazio: nenhuma demanda cadastrada" do
    get demands_path
    assert_select ".empty", /Nenhuma demanda cadastrada/
    assert_select ".empty a.btn--primary[href=?]", new_demand_path
  end

  test "estado vazio: nenhum resultado oferece Limpar filtros" do
    demand(title: "existe")
    get demands_path(q: "naoexiste")
    assert_select ".empty", /Nenhuma demanda para os filtros atuais/
    assert_select ".empty a[href=?]", demands_path, /Limpar filtros/
  end

  # --- integridade ---------------------------------------------------------

  test "sem N+1: demands da página em consulta única (independe da quantidade)" do
    10.times { |i| demand(title: "D#{i}") }
    q = count_queries(/FROM "demands"/) { get demands_path(per_page: 50) }
    assert_response :success
    assert q <= 2, "esperava ≤2 queries em demands, obteve #{q}"
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
