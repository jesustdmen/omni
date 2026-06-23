require "test_helper"

# PB-007 — lista operacional de /projects: busca, filtros, paginação, ações, duplicação.
class ProjectsListTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @acme = Client.create!(name: "ACME")
    @globex = Client.create!(name: "Globex")
  end

  def project(attrs = {})
    base = { client: @acme, name: "Projeto", status: "planning" }
    Project.create!(base.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    get projects_path
    assert_redirected_to new_user_session_path
  end

  # --- busca ---------------------------------------------------------------

  test "busca por nome" do
    project(name: "Portal do Cliente")
    project(name: "App Mobile")
    get projects_path(q: "portal")
    assert_select "td.projects-list__name", /Portal do Cliente/
    assert_select "td.projects-list__name", { text: /App Mobile/, count: 0 }
  end

  test "busca por descrição" do
    project(name: "P1", description: "integração com xyzzy")
    project(name: "P2", description: "nada")
    get projects_path(q: "xyzzy")
    assert_select "td.projects-list__name", /P1/
    assert_select "td.projects-list__name", { text: /P2/, count: 0 }
  end

  test "busca case-insensitive" do
    project(name: "Migração Banco")
    get projects_path(q: "migração")
    assert_select "td.projects-list__name", /Migração Banco/
  end

  test "% e _ tratados como texto" do
    project(name: "Promo 10% off")
    project(name: "sem cifra")
    get projects_path(q: "10%")
    assert_select "td.projects-list__name", /10% off/
    assert_select "td.projects-list__name", { text: /sem cifra/, count: 0 }
    project(name: "build_final")
    project(name: "buildXfinal")
    get projects_path(q: "build_final")
    assert_select "td.projects-list__name", /build_final/
    assert_select "td.projects-list__name", { text: /buildXfinal/, count: 0 }
  end

  # --- filtros -------------------------------------------------------------

  test "filtro por cliente" do
    project(name: "Da ACME", client: @acme)
    project(name: "Da Globex", client: @globex)
    get projects_path(client_id: @globex.id)
    assert_select "td.projects-list__name", /Da Globex/
    assert_select "td.projects-list__name", { text: /Da ACME/, count: 0 }
  end

  test "filtro por status" do
    project(name: "Em andamento", status: "in_progress")
    project(name: "Planejando", status: "planning")
    get projects_path(status: "in_progress")
    assert_select "td.projects-list__name", /Em andamento/
    assert_select "td.projects-list__name", { text: /Planejando/, count: 0 }
  end

  test "combinação busca + filtros" do
    project(name: "Bug fiscal", status: "on_hold", client: @acme)
    project(name: "Bug fiscal", status: "completed", client: @acme)
    project(name: "Bug contábil", status: "on_hold", client: @acme)
    get projects_path(q: "fiscal", status: "on_hold", client_id: @acme.id)
    assert_select "tbody tr", 1
    assert_select "td.projects-list__name", /Bug fiscal/
  end

  test "status inválido ignorado" do
    project(name: "A"); project(name: "B")
    get projects_path(status: "xxx")
    assert_select "tbody tr", 2
  end

  # --- paginação -----------------------------------------------------------

  test "per_page limita; página inválida volta para 1; ordem name asc" do
    %w[C B A].each { |n| project(name: n) }
    9.times { |i| project(name: "Z#{i}") }
    get projects_path(per_page: 10)
    assert_select "tbody tr", 10
    names = css_select("td.projects-list__name a").map(&:text)
    assert_equal %w[A B C], names.first(3) # name asc
    get projects_path(per_page: 10, page: 999)
    assert_select ".pagination__status", /Página 1 de/
  end

  test "links de paginação preservam busca/filtros/per_page" do
    15.times { project(name: "Proj X", status: "planning", client: @acme) }
    get projects_path(q: "Proj", status: "planning", client_id: @acme.id, per_page: 10)
    assert_select "a", text: /Próxima/ do |els|
      href = els.first["href"]
      assert_match(/q=Proj/, href)
      assert_match(/status=planning/, href)
      assert_match(/client_id=#{@acme.id}/, href)
      assert_match(/per_page=10/, href)
      assert_match(/page=2/, href)
    end
  end

  # --- lista / ações -------------------------------------------------------

  test "tabela mostra período, orçamento e trecho da descrição" do
    project(name: "Com período", description: "uma descrição", budget: "R$ 10.000",
            start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 3, 1))
    get projects_path
    assert_select "td.projects-list__name .projects-list__excerpt", /uma descrição/
    assert_select "td", /01\/01\/2026 → 01\/03\/2026/
    assert_select "td", /R\$ 10\.000/
  end

  test "ações Ver/Editar/Duplicar/Excluir + Novo destacado" do
    p = project(name: "Com ações")
    get projects_path
    assert_select "a.btn--primary[href=?]", new_project_path, /Novo projeto/
    assert_select ".te-actions a[href^=?]", project_path(p)       # Ver (+ return_to, PB-013b)
    assert_select ".te-actions a[href^=?]", edit_project_path(p)  # Editar (+ return_to)
    assert_select ".te-actions form[action=?]", duplicate_project_path(p)
    assert_select ".te-actions form[action=?][method=post]", project_path(p) do
      assert_select "input[name=_method][value=delete]", true
    end
  end

  # --- estados vazios ------------------------------------------------------

  test "estado vazio: nenhum projeto cadastrado" do
    get projects_path
    assert_select ".empty", /Nenhum projeto cadastrado/
  end

  test "estado vazio por filtro oferece Limpar filtros" do
    project(name: "existe")
    get projects_path(q: "naoexiste")
    assert_select ".empty", /Nenhum projeto para os filtros atuais/
    assert_select ".empty a[href=?]", projects_path, /Limpar filtros/
  end

  # --- formulário (select de status) ---------------------------------------

  test "form usa select de status (não campo livre) com labels PT-BR" do
    get new_project_path
    assert_select "select[name=?]", "project[status]"
    assert_select "select[name='project[status]'] option[value=in_progress]", /Em andamento/
    assert_select "input[type=text][name='project[status]']", count: 0
  end

  test "validação: término não pode anteceder início" do
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { client_id: @acme.id, name: "X", status: "planning",
                                               start_date: "2026-03-01", end_date: "2026-01-01" } }
    end
    assert_response :unprocessable_entity
  end

  test "status inválido no create é barrado (inclusion)" do
    assert_no_difference "Project.count" do
      post projects_path, params: { project: { client_id: @acme.id, name: "X", status: "qualquer" } }
    end
    assert_response :unprocessable_entity
  end

  # --- duplicação -----------------------------------------------------------

  test "duplicar copia só cliente/descrição/nome (cópia); status planning; sem datas/orçamento/tarefas" do
    orig = project(name: "Original", description: "desc", status: "completed",
                   budget: "R$ 99", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 2, 1))
    orig.tasks.create!(client: @acme, title: "T", type: "support")
    assert_difference "Project.count", 1 do
      post duplicate_project_path(orig)
    end
    copy = Project.order(:created_at).last
    assert_equal "Original (cópia)", copy.name
    assert_equal "desc", copy.description
    assert_equal @acme.id, copy.client_id
    assert_equal "planning", copy.status
    assert_nil copy.budget
    assert_nil copy.start_date
    assert_nil copy.end_date
    assert_equal 0, copy.tasks.count
    assert_redirected_to edit_project_path(copy)
  end

  test "duplicar exige autenticação" do
    sign_out @user
    p = project(name: "P")
    assert_no_difference "Project.count" do
      post duplicate_project_path(p)
    end
    assert_redirected_to new_user_session_path
  end

  # --- integridade ---------------------------------------------------------

  test "sem N+1: projetos da página em consulta única" do
    5.times { |i| project(name: "P#{i}") }
    q = count_queries(/FROM "projects"/) { get projects_path(per_page: 50) }
    assert_response :success
    assert q <= 2, "esperava ≤2 queries em projects, obteve #{q}"
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
