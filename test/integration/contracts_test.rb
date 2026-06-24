require "test_helper"

# PB-019b — CRUD de Contratos (padrão Omni) + sidebar + filtros.
class ContractsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
    @provider = ProviderCompany.create!(name: "Presta A")
    @client = Client.create!(name: "Cliente A")
    @project = @client.projects.create!(name: "Proj A1", status: "planning")
  end

  def valid_params(**overrides)
    { provider_company_id: @provider.id, client_id: @client.id, project_id: "",
      start_date: "2026-01-01", end_date: "2026-06-30", status: "active",
      hourly_rate: "150.00", notes: "obs" }.merge(overrides)
  end

  # --- Navegação / lista ---
  test "sidebar tem item Contratos" do
    get root_path
    assert_select "a[href=?]", contracts_path, text: /Contratos/
  end

  test "index lista contratos com ação Novo contrato" do
    Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100, status: "active", start_date: Date.new(2026, 1, 1))
    get contracts_path
    assert_response :success
    assert_select "h1", "Contratos"
    assert_select "a[href=?]", new_contract_path(return_to: contracts_path), text: /Novo contrato/
    assert_match @client.name, response.body
  end

  test "index vazio mostra estado vazio" do
    get contracts_path
    assert_select ".empty"
  end

  # --- Criação ---
  test "new renderiza o formulário" do
    get new_contract_path
    assert_response :success
    assert_select "select[name='contract[provider_company_id]']"
    assert_select "select[name='contract[client_id]']"
    assert_select "input[name='contract[hourly_rate]']"
  end

  test "cria contrato válido (geral, sem projeto)" do
    assert_difference("Contract.count", 1) do
      post contracts_path, params: { contract: valid_params }
    end
    c = Contract.last
    assert_nil c.project_id
    assert_equal "active", c.status
    assert_redirected_to contract_path(c)
  end

  test "cria contrato de projeto" do
    assert_difference("Contract.count", 1) do
      post contracts_path, params: { contract: valid_params(project_id: @project.id) }
    end
    assert_equal @project.id, Contract.last.project_id
  end

  test "hourly_rate ausente: 422 + erros (não cria)" do
    assert_no_difference("Contract.count") do
      post contracts_path, params: { contract: valid_params(hourly_rate: "") }
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "sobreposição de geral é bloqueada pela UI" do
    Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100,
                     status: "active", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 6, 30))
    assert_no_difference("Contract.count") do
      post contracts_path, params: { contract: valid_params(start_date: "2026-05-01", end_date: "2026-12-31") }
    end
    assert_response :unprocessable_entity
  end

  test "projeto de outro cliente é rejeitado pela UI" do
    other = Client.create!(name: "Outro")
    op = other.projects.create!(name: "OP", status: "planning")
    assert_no_difference("Contract.count") do
      post contracts_path, params: { contract: valid_params(project_id: op.id) }
    end
    assert_response :unprocessable_entity
  end

  # --- Detalhe / edição / exclusão ---
  test "show exibe os dados do contrato" do
    c = Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100, status: "active", start_date: Date.new(2026, 1, 1))
    get contract_path(c)
    assert_response :success
    assert_match @provider.name, response.body
    assert_match "Ativo", response.body
  end

  test "edita contrato" do
    c = Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100, status: "draft", start_date: Date.new(2026, 1, 1))
    patch contract_path(c), params: { contract: valid_params(status: "active", hourly_rate: "200") }
    c.reload
    assert_equal "active", c.status
    assert_equal 200, c.hourly_rate
  end

  test "exclui contrato" do
    c = Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100, status: "active", start_date: Date.new(2026, 1, 1))
    assert_difference("Contract.count", -1) do
      delete contract_path(c)
    end
    assert_redirected_to contracts_path
  end

  # --- Filtros ---
  test "filtra por status e por cliente" do
    c2 = Client.create!(name: "Cliente B")
    Contract.create!(provider_company: @provider, client: @client, hourly_rate: 100, status: "active", start_date: Date.new(2026, 1, 1))
    Contract.create!(provider_company: @provider, client: c2, hourly_rate: 100, status: "ended", start_date: Date.new(2026, 1, 1))
    get contracts_path(status: "active")
    # checa a TABELA de resultados (o nome de outros clientes aparece no <select> de filtro)
    assert_select "table.projects-list td.projects-list__name", text: @client.name
    assert_select "table.projects-list td.projects-list__name", text: "Cliente B", count: 0
    get contracts_path(client_id: c2.id)
    assert_select "table.projects-list td.projects-list__name", text: "Cliente B"
  end

  # --- Autorização ---
  test "exige autenticação" do
    sign_out @user
    get contracts_path
    assert_redirected_to new_user_session_path
    post contracts_path, params: { contract: valid_params }
    assert_redirected_to new_user_session_path
  end

  # --- Escopo negativo: TimeEntry intacto ---
  test "TimeEntry não tem coluna de contrato/valor (escopo negativo)" do
    assert_not TimeEntry.column_names.include?("contract_id")
    assert_not TimeEntry.column_names.include?("hourly_rate")
    assert_not TimeEntry.column_names.include?("amount")
  end
end
