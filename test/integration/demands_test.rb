require "test_helper"

class DemandsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    sign_in @user
    @client = Client.create!(name: "ACME")
  end

  test "exige autenticação" do
    sign_out @user
    get demands_path
    assert_redirected_to new_user_session_path
  end

  test "index renderiza" do
    Demand.create!(title: "Bug fiscal", origin: "email", priority: "high", client: @client)
    get demands_path
    assert_response :success
    assert_select "h1", "Demandas"
    assert_select "td", /Bug fiscal/
  end

  test "new renderiza formulário com selects" do
    get new_demand_path
    assert_response :success
    assert_select "form"
    assert_select "select[name=?]", "demand[origin]"
    assert_select "select[name=?]", "demand[priority]"
    assert_select "select[name=?]", "demand[client_id]"
  end

  test "create válido" do
    assert_difference "Demand.count", 1 do
      post demands_path, params: { demand: { title: "D", origin: "email", priority: "low", client_id: @client.id } }
    end
    assert_response :redirect
  end

  test "create inválido mostra erro" do
    assert_no_difference "Demand.count" do
      post demands_path, params: { demand: { title: "", origin: "email", priority: "low" } }
    end
    assert_response :unprocessable_entity
    assert_select "div.errors"
  end

  test "show mostra dados e botão converter quando pending" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    get demand_path(demand)
    assert_response :success
    assert_select "h1", "D"
    assert_select "dd", /ACME/
    assert_select "div.convert"
  end

  test "show não mostra botão converter quando convertida" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    ConvertDemand.call(demand)
    get demand_path(demand.reload)
    assert_response :success
    assert_select "div.convert", count: 0
    assert_select ".converted-state"
  end

  test "edit e update" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    get edit_demand_path(demand)
    assert_response :success
    patch demand_path(demand), params: { demand: { title: "D2" } }
    assert_redirected_to demand_path(demand)
    assert_equal "D2", demand.reload.title
  end

  test "destroy" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    assert_difference "Demand.count", -1 do
      delete demand_path(demand)
    end
    assert_redirected_to demands_path
  end

  test "convert: sucesso redireciona para a task" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    assert_difference "Task.count", 1 do
      post convert_demand_path(demand)
    end
    assert demand.reload.converted?
    assert_not_nil demand.converted_at
    assert_redirected_to task_path(Task.last)
  end

  test "convert: sem cliente falha sem criar task" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low")
    assert_no_difference "Task.count" do
      post convert_demand_path(demand)
    end
    assert_redirected_to demand_path(demand)
    assert_equal "pending", demand.reload.status
  end

  test "convert: já convertida não duplica" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    post convert_demand_path(demand)
    assert_equal 1, Task.count
    post convert_demand_path(demand.reload)
    assert_equal 1, Task.count
    assert_redirected_to demand_path(demand)
  end
end
