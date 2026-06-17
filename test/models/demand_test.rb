require "test_helper"

class DemandTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "ACME")
  end

  def build_demand(attrs = {})
    Demand.new({ title: "D", origin: "email", priority: "low" }.merge(attrs))
  end

  test "title obrigatório" do
    assert_not build_demand(title: nil).valid?
  end

  test "origin obrigatório" do
    assert_not build_demand(origin: nil).valid?
  end

  test "origin aceita somente valores permitidos" do
    assert_not build_demand(origin: "bogus").valid?
    Demand::ORIGINS.each { |o| assert build_demand(origin: o).valid?, "#{o} deveria ser válido" }
  end

  test "priority obrigatório" do
    assert_not build_demand(priority: nil).valid?
  end

  test "priority aceita somente valores permitidos" do
    assert_not build_demand(priority: "bogus").valid?
    Demand::PRIORITIES.each { |p| assert build_demand(priority: p).valid?, "#{p} deveria ser válido" }
  end

  test "status default é pending" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low")
    assert_equal "pending", demand.status
  end

  test "status aceita somente pending e converted" do
    assert_not build_demand(status: "bogus").valid?
    %w[pending converted].each { |s| assert build_demand(status: s).valid?, "#{s} deveria ser válido" }
  end

  test "client é opcional" do
    assert build_demand.valid?
  end

  test "ao excluir client, client_id da demand fica nil" do
    demand = Demand.create!(title: "D", origin: "email", priority: "low", client: @client)
    @client.destroy
    assert_nil demand.reload.client_id
    assert Demand.exists?(demand.id)
  end
end
