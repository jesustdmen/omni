require "test_helper"

class TaskPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    @client = Client.create!(name: "ACME")
    @task = @client.tasks.create!(title: "T", type: "support")
  end

  test "usuário autenticado acessa" do
    assert TaskPolicy.new(@user, @task).show?
    assert TaskPolicy.new(@user, @task).create?
    assert TaskPolicy.new(@user, @task).update?
    assert TaskPolicy.new(@user, @task).destroy?
  end

  test "anônimo não acessa" do
    assert_not TaskPolicy.new(nil, @task).show?
    assert_not TaskPolicy.new(nil, @task).update?
  end

  test "scope: autenticado vê, anônimo não" do
    assert_equal 1, TaskPolicy::Scope.new(@user, Task).resolve.count
    assert_equal 0, TaskPolicy::Scope.new(nil, Task).resolve.count
  end
end
