require "test_helper"

# PB-019a — CRUD da Empresa Prestadora (padrão Omni: lista + páginas Nova/Editar),
# acessível a partir de Configurações.
class ProviderCompaniesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
  end

  # --- Acesso por Configurações (hub) ---
  test "hub de Configurações tem card/atalho para Empresas Prestadoras" do
    get settings_path
    assert_response :success
    assert_select "a[href=?]", provider_companies_path, text: /Gerenciar/
  end

  test "regressão: hub de Configurações linka sync e status (em sub-páginas próprias)" do
    get settings_path
    assert_select "a[href=?]", settings_sync_path   # PB-016b
    assert_select "a[href=?]", settings_status_path # PB-018
  end

  # --- Lista ---
  test "index lista empresas e tem ação Nova empresa" do
    ProviderCompany.create!(name: "Acme Serviços LTDA", cnpj: "11222333000144")
    get provider_companies_path
    assert_response :success
    assert_select "h1", "Empresas prestadoras"
    assert_select "a[href=?]", new_provider_company_path(return_to: provider_companies_path), text: /Nova empresa/
    assert_match "Acme Serviços LTDA", response.body
    assert_match "11.222.333/0001-44", response.body # CNPJ formatado
  end

  test "index vazio mostra estado vazio" do
    get provider_companies_path
    assert_select ".empty"
  end

  # --- Criar ---
  test "new renderiza o formulário" do
    get new_provider_company_path
    assert_response :success
    assert_select "form input[name='provider_company[name]']"
  end

  test "cria empresa prestadora válida" do
    assert_difference("ProviderCompany.count", 1) do
      post provider_companies_path, params: {
        provider_company: { name: "Acme Serviços LTDA", trade_name: "Acme",
                            cnpj: "11.222.333/0001-44", email: "x@acme.com", phone: "11999990000",
                            address: "Rua A, 1", active: true }
      }
    end
    pc = ProviderCompany.find_by(name: "Acme Serviços LTDA")
    assert_equal "11222333000144", pc.cnpj
    assert_redirected_to provider_companies_path
  end

  test "name obrigatório: re-renderiza new com erro (não cria)" do
    assert_no_difference("ProviderCompany.count") do
      post provider_companies_path, params: { provider_company: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select ".errors"
  end

  test "cnpj vazio vira nil ao criar" do
    post provider_companies_path, params: { provider_company: { name: "Sem CNPJ", cnpj: "  " } }
    assert_nil ProviderCompany.find_by(name: "Sem CNPJ").cnpj
  end

  test "cnpj duplicado entre prestadoras é bloqueado" do
    ProviderCompany.create!(name: "Primeira", cnpj: "11222333000144")
    assert_no_difference("ProviderCompany.count") do
      post provider_companies_path, params: { provider_company: { name: "Segunda", cnpj: "11.222.333/0001-44" } }
    end
    assert_response :unprocessable_entity
  end

  test "cnpj igual ao de um Client é aceito" do
    Client.create!(name: "Cliente X", cnpj: "11222333000144")
    assert_difference("ProviderCompany.count", 1) do
      post provider_companies_path, params: { provider_company: { name: "Prestadora X", cnpj: "11222333000144" } }
    end
  end

  # --- Editar / ativar-inativar ---
  test "edit renderiza o formulário preenchido" do
    pc = ProviderCompany.create!(name: "Velho Nome")
    get edit_provider_company_path(pc)
    assert_response :success
    assert_select "input[name='provider_company[name]'][value=?]", "Velho Nome"
  end

  test "atualiza empresa prestadora" do
    pc = ProviderCompany.create!(name: "Velho Nome")
    patch provider_company_path(pc), params: { provider_company: { name: "Novo Nome", trade_name: "NN" } }
    pc.reload
    assert_equal "Novo Nome", pc.name
    assert_equal "NN", pc.trade_name
    assert_redirected_to provider_companies_path
  end

  test "ativa/inativa empresa prestadora" do
    pc = ProviderCompany.create!(name: "Toggle", active: true)
    patch provider_company_path(pc), params: { provider_company: { active: false } }
    assert_not pc.reload.active?
  end

  # --- Excluir ---
  test "exclui empresa prestadora (sem vínculos)" do
    pc = ProviderCompany.create!(name: "Apagável")
    assert_difference("ProviderCompany.count", -1) do
      delete provider_company_path(pc)
    end
    assert_redirected_to provider_companies_path
  end

  # --- Autorização ---
  test "exige autenticação na lista e na criação" do
    sign_out @user
    get provider_companies_path
    assert_redirected_to new_user_session_path
    post provider_companies_path, params: { provider_company: { name: "X" } }
    assert_redirected_to new_user_session_path
  end

  test "policy: usuário autenticado pode gerenciar" do
    pc = ProviderCompany.create!(name: "P")
    assert ProviderCompanyPolicy.new(@user, pc).update?
    assert ProviderCompanyPolicy.new(@user, pc).destroy?
    assert ProviderCompanyPolicy.new(@user, ProviderCompany.new).create?
    assert ProviderCompanyPolicy.new(@user, ProviderCompany).index?
  end
end
