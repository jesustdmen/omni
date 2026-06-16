require "test_helper"

class ClientPolicyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(username: "u", email: "u@example.com", password: "secret123")
    @client = Client.create!(name: "ACME")
  end

  test "usuário autenticado acessa" do
    assert ClientPolicy.new(@user, @client).show?
    assert ClientPolicy.new(@user, @client).create?
    assert ClientPolicy.new(@user, @client).update?
    assert ClientPolicy.new(@user, @client).destroy?
  end

  test "sem usuário não acessa" do
    assert_not ClientPolicy.new(nil, @client).show?
    assert_not ClientPolicy.new(nil, @client).update?
  end

  test "scope sem usuário retorna vazio" do
    assert_equal 0, ClientPolicy::Scope.new(nil, Client).resolve.count
    assert_equal 1, ClientPolicy::Scope.new(@user, Client).resolve.count
  end
end
