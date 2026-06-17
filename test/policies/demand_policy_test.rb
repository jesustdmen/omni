require "test_helper"

class DemandPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    @demand = Demand.create!(title: "D", origin: "email", priority: "low")
  end

  test "usuário autenticado acessa (inclui convert)" do
    assert DemandPolicy.new(@user, @demand).show?
    assert DemandPolicy.new(@user, @demand).create?
    assert DemandPolicy.new(@user, @demand).update?
    assert DemandPolicy.new(@user, @demand).destroy?
    assert DemandPolicy.new(@user, @demand).convert?
  end

  test "anônimo não acessa" do
    assert_not DemandPolicy.new(nil, @demand).show?
    assert_not DemandPolicy.new(nil, @demand).convert?
  end

  test "scope: autenticado vê, anônimo não" do
    assert_equal 1, DemandPolicy::Scope.new(@user, Demand).resolve.count
    assert_equal 0, DemandPolicy::Scope.new(nil, Demand).resolve.count
  end
end
