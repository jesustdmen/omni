require "test_helper"

class ClientsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    sign_in @user
  end

  test "exige autenticação" do
    sign_out @user
    get clients_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    Client.create!(name: "ACME")
    get clients_path
    assert_response :success
    assert_select "h1", "Clientes"
    assert_select "td", /ACME/
  end

  test "new renderiza formulário" do
    get new_client_path
    assert_response :success
    assert_select "form"
    assert_select "input[name=?]", "client[name]"
  end

  test "create válido redireciona" do
    assert_difference "Client.count", 1 do
      post clients_path, params: { client: { name: "ACME", cnpj: "12345678000199" } }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "Client.count" do
      post clients_path, params: { client: { name: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "show mostra dados" do
    client = Client.create!(name: "ACME", cnpj: "12345678000199")
    get client_path(client)
    assert_response :success
    assert_select "h1", "ACME"
    assert_select "dd", /12345678000199/
  end

  test "edit e update" do
    client = Client.create!(name: "ACME")
    get edit_client_path(client)
    assert_response :success
    patch client_path(client), params: { client: { name: "ACME 2" } }
    assert_redirected_to client_path(client)
    assert_equal "ACME 2", client.reload.name
  end

  test "destroy" do
    client = Client.create!(name: "ACME")
    assert_difference "Client.count", -1 do
      delete client_path(client)
    end
    assert_redirected_to clients_path
  end
end
