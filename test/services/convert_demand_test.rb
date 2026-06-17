require "test_helper"

class ConvertDemandTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  def pending_demand(attrs = {})
    Demand.create!({ title: "Suporte X", description: "detalhe", origin: "email", priority: "high", client: @client }.merge(attrs))
  end

  test "conversão válida cria task" do
    demand = pending_demand
    assert_difference "Task.count", 1 do
      result = ConvertDemand.call(demand)
      assert result.success?
    end
  end

  test "conversão válida marca demand como converted e preenche converted_at" do
    demand = pending_demand
    ConvertDemand.call(demand)
    demand.reload
    assert demand.converted?
    assert_not_nil demand.converted_at
  end

  test "task criada espelha a demand (type support, status pending, mesmos dados)" do
    demand = pending_demand
    result = ConvertDemand.call(demand)
    task = result.task
    assert_equal "support", task.type
    assert_equal "pending", task.status
    assert_equal @client.id, task.client_id
    assert_equal demand.title, task.title
    assert_equal demand.description, task.description
    assert_nil task.project_id
  end

  test "demand sem client não converte" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low")
    assert_no_difference "Task.count" do
      result = ConvertDemand.call(demand)
      assert_not result.success?
    end
    assert_equal "pending", demand.reload.status
    assert_nil demand.converted_at
  end

  test "demand já convertida não converte novamente" do
    demand = pending_demand
    ConvertDemand.call(demand)
    assert_no_difference "Task.count" do
      result = ConvertDemand.call(demand.reload)
      assert_not result.success?
    end
  end

  test "conversão é atômica: rollback completo se update da demand falhar após criar task" do
    demand = pending_demand
    # Stub controlado (override de singleton): força a atualização da demand a
    # falhar APÓS a task ser criada, dentro da transação.
    def demand.update!(*, **)
      raise ActiveRecord::RecordInvalid.new(self)
    end

    result = ConvertDemand.call(demand)
    assert_not result.success?
    assert_equal 0, Task.count, "task criada deve ter sofrido rollback"
    assert_equal "pending", demand.reload.status
    assert_nil demand.reload.converted_at
  end
end
