require "test_helper"

# PB-006 — listas operacionais de /clients (abas Empresas/Contatos) + 1 principal/cliente.
class ClientsContactsListTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @acme = Client.create!(name: "ACME LTDA", trade_name: "Acme", cnpj: "12345678000199", phone: "1133334444", status: "active")
    @globex = Client.create!(name: "GLOBEX SA", trade_name: "Globex", cnpj: "98765432000100", status: "inactive")
  end

  def contact(client, attrs = {})
    client.contacts.create!({ name: "Fulano", email: "f@x.com" }.merge(attrs))
  end

  test "exige autenticação" do
    sign_out @user
    get clients_path
    assert_redirected_to new_user_session_path
  end

  test "abas: default companies; tab=contacts ativa contatos" do
    get clients_path
    assert_select ".tab--active", /Empresas/
    get clients_path(tab: "contacts")
    assert_select ".tab--active", /Contatos/
  end

  # --- empresas: busca ------------------------------------------------------

  test "busca empresa por nome/razão social" do
    get clients_path(q: "acme")
    assert_select "td.companies-list__name", /ACME LTDA/
    assert_select "td.companies-list__name", { text: /GLOBEX/, count: 0 }
  end

  test "busca empresa por nome fantasia" do
    get clients_path(q: "globex")
    assert_select "td.companies-list__name", /GLOBEX SA/
    assert_select "td.companies-list__name", { text: /ACME/, count: 0 }
  end

  test "busca empresa por CNPJ com e sem pontuação" do
    get clients_path(q: "12345678000199")
    assert_select "td.companies-list__name", /ACME LTDA/
    get clients_path(q: "12.345.678/0001-99")
    assert_select "td.companies-list__name", /ACME LTDA/
    assert_select "td.companies-list__name", { text: /GLOBEX/, count: 0 }
  end

  test "% e _ tratados como texto na busca de empresa" do
    Client.create!(name: "Desconto 50% Cia")
    get clients_path(q: "50%")
    assert_select "td.companies-list__name", /50% Cia/
    assert_select "td.companies-list__name", { text: /ACME/, count: 0 }
  end

  test "filtro por status (empresa)" do
    get clients_path(status: "inactive")
    assert_select "td.companies-list__name", /GLOBEX SA/
    assert_select "td.companies-list__name", { text: /ACME/, count: 0 }
  end

  test "status inválido ignorado (empresa)" do
    get clients_path(status: "xxx")
    assert_select "tbody tr", 2
  end

  test "empresa mostra contato principal na coluna" do
    contact(@acme, name: "Maria Principal", is_primary: true)
    get clients_path
    assert_select "td", /Maria Principal/
  end

  # --- contatos -------------------------------------------------------------

  test "busca contato por nome/email/telefone/cargo" do
    contact(@acme, name: "João Silva", email: "joao@acme.com", phone: "1199998888", position: "Gerente")
    contact(@globex, name: "Outro", email: "o@g.com")
    get clients_path(tab: "contacts", q: "joão");    assert_select "td", /João Silva/
    get clients_path(tab: "contacts", q: "joao@acme"); assert_select "td", /João Silva/
    get clients_path(tab: "contacts", q: "1199998888"); assert_select "td", /João Silva/
    get clients_path(tab: "contacts", q: "gerente");  assert_select "td", /João Silva/
  end

  test "filtro contato por cliente" do
    contact(@acme, name: "Da ACME")
    contact(@globex, name: "Da Globex")
    get clients_path(tab: "contacts", client_id: @globex.id)
    assert_select "td", /Da Globex/
    assert_select "td", { text: /Da ACME/, count: 0 }
  end

  test "filtro contato por status do cliente" do
    contact(@acme, name: "Ativo cli")
    contact(@globex, name: "Inativo cli")
    get clients_path(tab: "contacts", status: "inactive")
    assert_select "td", /Inativo cli/
    assert_select "td", { text: /Ativo cli/, count: 0 }
  end

  test "filtro contato principal sim/não" do
    contact(@acme, name: "Principal A", is_primary: true)
    contact(@acme, name: "Secundario A", is_primary: false)
    get clients_path(tab: "contacts", primary: "yes")
    assert_select "td", /Principal A/
    assert_select "td", { text: /Secundario A/, count: 0 }
    get clients_path(tab: "contacts", primary: "no")
    assert_select "td", /Secundario A/
  end

  # --- paginação ------------------------------------------------------------

  test "paginação empresas: per_page e página inválida volta para 1" do
    12.times { |i| Client.create!(name: "C#{format('%02d', i)}") }
    get clients_path(per_page: 10)
    assert_select "tbody tr", 10
    assert_select ".pagination__status", /Página 1 de/
    get clients_path(per_page: 10, page: 999)
    assert_select ".pagination__status", /Página 1 de/
  end

  test "links de paginação preservam tab/busca/filtros/per_page" do
    15.times { |i| Client.create!(name: "Empresa #{i}", status: "active") }
    get clients_path(q: "Empresa", status: "active", per_page: 10)
    assert_select "a", text: /Próxima/ do |els|
      href = els.first["href"]
      assert_match(/tab=companies/, href)
      assert_match(/q=Empresa/, href)
      assert_match(/status=active/, href)
      assert_match(/per_page=10/, href)
      assert_match(/page=2/, href)
    end
  end

  # --- ações / vazios -------------------------------------------------------

  test "ações empresa Ver/Editar/Excluir + Novo cliente destacado" do
    get clients_path
    assert_select "a.btn--primary[href=?]", new_client_path, /Novo cliente/
    assert_select ".te-actions a[href^=?]", client_path(@acme)        # Ver (+ return_to, PB-013b)
    assert_select ".te-actions a[href^=?]", edit_client_path(@acme)   # Editar (+ return_to)
    assert_select ".te-actions form[action=?][method=post]", client_path(@acme) do
      assert_select "input[name=_method][value=delete]", true
      assert_select "input[name=return_to]", true                     # PB-013b — contexto
    end
  end

  test "ações contato Editar/Excluir + link p/ cliente" do
    c = contact(@acme, name: "Zé")
    get clients_path(tab: "contacts")
    assert_select ".te-actions a[href^=?]", edit_client_contact_path(@acme, c) # + return_to (PB-013b)
    assert_select "td a[href=?]", client_path(@acme), /ACME/
  end

  test "estado vazio empresas e contatos" do
    Client.destroy_all
    get clients_path
    assert_select ".empty", /Nenhum cliente cadastrado/
    get clients_path(tab: "contacts")
    assert_select ".empty", /Nenhum contato cadastrado/
  end

  test "estado vazio por filtro oferece Limpar filtros" do
    get clients_path(q: "naoexiste")
    assert_select ".empty", /Nenhuma empresa para os filtros atuais/
    assert_select ".empty a[href=?]", clients_path(tab: "companies"), /Limpar filtros/
  end

  # --- integridade / N+1 ----------------------------------------------------

  test "sem N+1 nas empresas: contatos pré-carregados (1 query de contacts, não por linha)" do
    5.times { |i| c = Client.create!(name: "E#{i}"); c.contacts.create!(name: "p", email: "p@x.com", is_primary: true) }
    # com includes(:contacts), os contatos da página vêm em UMA query, independente
    # do nº de empresas (sem N+1 na coluna "contato principal").
    q = count_queries(/FROM "contacts"/) { get clients_path(per_page: 50) }
    assert_response :success
    assert q <= 1, "esperava ≤1 query em contacts (preload), obteve #{q}"
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
