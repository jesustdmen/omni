require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    @client = Client.create!(name: "ACME")
    @project = @client.projects.create!(name: "Portal")
  end

  test "usuário autenticado acessa" do
    assert ProjectPolicy.new(@user, @project).show?
    assert ProjectPolicy.new(@user, @project).create?
    assert ProjectPolicy.new(@user, @project).update?
    assert ProjectPolicy.new(@user, @project).destroy?
  end

  test "anônimo não acessa" do
    assert_not ProjectPolicy.new(nil, @project).show?
    assert_not ProjectPolicy.new(nil, @project).update?
  end

  test "scope: autenticado vê, anônimo não" do
    assert_equal 1, ProjectPolicy::Scope.new(@user, Project).resolve.count
    assert_equal 0, ProjectPolicy::Scope.new(nil, Project).resolve.count
  end
end
