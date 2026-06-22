require "test_helper"

# PB-013b — preservação de contexto/navegação (return_to) entre listas, busca,
# detalhes, formulários e ações. Cobre os fluxos A/B/C, cancelar, erro de validação,
# exclusão, paginação/per_page, aba Empresas/Contatos, busca global, contatos e
# apontamentos por origem, breadcrumbs acessíveis e autenticação.
class NavigationContextTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME LTDA", trade_name: "Acme", cnpj: "12345678000199", status: "active")
    @task = @client.tasks.create!(title: "Corrigir relatório", type: "support", status: "todo")
  end

  # --- autenticação ----------------------------------------------------------

  test "rotas continuam exigindo autenticação" do
    sign_out @user
    get task_path(@task, return_to: "/tasks?page=2")
    assert_redirected_to new_user_session_path
  end

  # --- listas carregam return_to (busca/filtros/paginação/aba) ---------------

  test "lista de tarefas: links Ver/Editar/Excluir carregam return_to=fullpath" do
    ctx = "/tasks?q=relat%C3%B3rio&status=todo&page=1"
    get ctx
    assert_response :success
    assert_select "a.te-action--view[href*=?]", "return_to="
    assert_select "a.te-action--edit[href*=?]", "return_to="
    # exclusão por button_to → hidden field return_to
    assert_select "form.inline input[name=return_to]"
  end

  test "lista de clientes (aba Empresas) propaga aba/filtros no return_to" do
    get clients_path(tab: "companies", q: "acme", per_page: 25)
    assert_response :success
    assert_select "a.te-action--view[href*=?]", "tab%3Dcompanies"
  end

  test "lista de clientes (aba Contatos) propaga return_to com a aba" do
    @client.contacts.create!(name: "João", email: "joao@acme.com")
    get clients_path(tab: "contacts", q: "joao")
    assert_response :success
    assert_select "a.te-action--edit[href*=?]", "tab%3Dcontacts"
  end

  # --- Fluxo: lista filtrada → detalhe → Voltar volta à origem exata ---------

  test "A: detalhe vindo da lista filtrada; Voltar e breadcrumb retornam à origem" do
    ctx = "/tasks?q=relat&status=todo&page=1"
    get task_path(@task, return_to: ctx)
    assert_response :success
    # "Voltar" e o breadcrumb "Tarefas" apontam para a origem exata
    assert_select "a.back-link[href=?]", ctx
    assert_select "nav.breadcrumb[aria-label=?] a[href=?]", "Breadcrumb", ctx
    # Editar propaga o contexto; Excluir o envia (no detalhe, via query da action do form)
    assert_select "a[href=?]", edit_task_path(@task, return_to: ctx)
    assert_select "form.inline[action*=?]", "return_to="
  end

  # --- Fluxo A: editar pela lista → salvar → mesma lista filtrada ------------

  test "A: update com return_to volta à lista filtrada (não ao detalhe)" do
    ctx = "/tasks?q=relat&status=todo&page=2"
    patch task_path(@task), params: { task: { title: "Novo" }, return_to: ctx }
    assert_redirected_to ctx
  end

  test "update sem return_to mantém o comportamento atual (detalhe)" do
    patch task_path(@task), params: { task: { title: "Novo" } }
    assert_redirected_to task_path(@task)
  end

  # --- Fluxo B: detalhe → editar → salvar → detalhe (return_to=detalhe) ------

  test "B: edição pelo detalhe preserva e o form carrega o hidden return_to" do
    detail = "/tasks/#{@task.id}"
    get edit_task_path(@task, return_to: detail)
    assert_response :success
    assert_select "form input[name=return_to][value=?]", detail
    patch task_path(@task), params: { task: { title: "Z" }, return_to: detail }
    assert_redirected_to detail
  end

  # --- Cancelar volta à origem ----------------------------------------------

  test "Cancelar no form aponta para a origem (return_to)" do
    ctx = "/tasks?status=todo"
    get edit_task_path(@task, return_to: ctx)
    assert_select "a.btn[href=?]", ctx, /Cancelar/
  end

  # --- Erro de validação mantém o contexto ----------------------------------

  test "erro de validação re-renderiza com o return_to preservado" do
    ctx = "/tasks?status=todo&page=3"
    patch task_path(@task), params: { task: { title: "" }, return_to: ctx }
    assert_response :unprocessable_entity
    assert_select "input[name=return_to][value=?]", ctx
  end

  # --- Exclusão retorna à origem --------------------------------------------

  test "destroy com return_to retorna à origem após sucesso" do
    ctx = "/tasks?status=todo&page=1"
    t = @client.tasks.create!(title: "Apagar", type: "support")
    delete task_path(t), params: { return_to: ctx }
    assert_redirected_to ctx
  end

  test "destroy sem return_to mantém o fallback (lista)" do
    t = @client.tasks.create!(title: "Apagar", type: "support")
    delete task_path(t)
    assert_redirected_to tasks_path
  end

  # --- Segurança: open redirect bloqueado em todas as ações ------------------

  test "update ignora return_to externo (open redirect) e usa fallback" do
    patch task_path(@task), params: { task: { title: "OK" }, return_to: "https://evil.example" }
    assert_redirected_to task_path(@task) # fallback, nunca a origem externa
  end

  test "destroy ignora return_to // (protocolo-relativo)" do
    t = @client.tasks.create!(title: "Apagar", type: "support")
    delete task_path(t), params: { return_to: "//evil.example" }
    assert_redirected_to tasks_path
  end

  # --- Busca global → resultado → Voltar volta à busca -----------------------

  test "busca: resultado carrega return_to=/search?q=..." do
    get search_path(q: "relat")
    assert_response :success
    assert_select "a.search-result__link[href*=?]", "return_to=%2Fsearch"
  end

  test "busca: detalhe aberto pela busca permite voltar à busca" do
    back = "/search?q=relat"
    get task_path(@task, return_to: back)
    assert_select "a.back-link[href=?]", back
  end

  # --- Contatos: retorno conforme origem ------------------------------------

  test "contato pela aba global volta a /clients?tab=contacts após salvar" do
    c = @client.contacts.create!(name: "João", email: "joao@acme.com")
    ctx = "/clients?tab=contacts&q=joao"
    patch client_contact_path(@client, c), params: { contact: { name: "João Silva" }, return_to: ctx }
    assert_redirected_to ctx
  end

  test "contato pelo cliente (sem return_to) volta ao cliente" do
    c = @client.contacts.create!(name: "João", email: "joao@acme.com")
    patch client_contact_path(@client, c), params: { contact: { name: "João S" } }
    assert_redirected_to @client
  end

  test "contato: criação pela aba global retorna à aba" do
    ctx = "/clients?tab=contacts"
    assert_difference "Contact.count", 1 do
      post client_contacts_path(@client), params: { contact: { name: "Novo", email: "n@acme.com" }, return_to: ctx }
    end
    assert_redirected_to ctx
  end

  # --- Apontamentos: retorno conforme origem --------------------------------

  test "apontamento aberto pela tarefa volta à tarefa (#tab-time)" do
    t = Time.current
    entry = @task.time_entries.create!(start_time: t, end_time: t + 60)
    back = task_path(@task, anchor: "tab-time")
    patch time_entry_path(entry), params: { time_entry: { description: "x" }, return_to: back }
    assert_redirected_to back
  end

  test "apontamento aberto pela lista global volta à lista" do
    t = Time.current
    entry = @task.time_entries.create!(start_time: t, end_time: t + 60)
    delete time_entry_path(entry), params: { return_to: "/time_entries" }
    assert_redirected_to "/time_entries"
  end

  test "apontamento sem return_to mantém fallback (lista global)" do
    t = Time.current
    entry = @task.time_entries.create!(start_time: t, end_time: t + 60)
    delete time_entry_path(entry)
    assert_redirected_to time_entries_path
  end

  # --- Paginação/per_page preservados no contexto ---------------------------

  test "paginação e per_page sobrevivem no return_to do detalhe ao Voltar" do
    ctx = "/tasks?page=2&per_page=25&status=todo"
    get task_path(@task, return_to: ctx)
    assert_select "a.back-link[href=?]", ctx
  end

  # --- Breadcrumbs acessíveis -----------------------------------------------

  test "breadcrumbs expõem aria-label=Breadcrumb e não exibem UUID" do
    get task_path(@task)
    assert_select "nav.breadcrumb[aria-label=?]", "Breadcrumb"
    # o rótulo do item atual é o título, nunca o UUID
    assert_select "nav.breadcrumb", { text: /#{Regexp.escape(@task.id)}/, count: 0 }
  end

  test "breadcrumb de demanda/projeto/cliente/apontamento/conversa são acessíveis" do
    demand = Demand.create!(title: "D1", origin: "email", priority: "low", client: @client)
    project = @client.projects.create!(name: "P1", status: "planning")
    t = Time.current
    entry = @task.time_entries.create!(start_time: t, end_time: t + 60)
    conv = Conversation.create!(thread_id: "tn-1", source: "claude", title: "C1", last_ts: Time.current)

    [ demand_path(demand), project_path(project), client_path(@client),
      time_entry_path(entry), conversation_path(conv) ].each do |path|
      get path
      assert_response :success
      assert_select 'nav.breadcrumb[aria-label="Breadcrumb"]', { minimum: 1 }, "faltou aria em #{path}"
    end
  end
end
