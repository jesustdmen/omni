require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  test "admin pode ver qualquer usuário" do
    admin = User.create!(username: "adm", email: "adm@example.com", password: "secret123", role: "admin")
    other = User.create!(username: "u1", email: "u1@example.com", password: "secret123")
    assert UserPolicy.new(admin, other).show?
  end

  test "usuário comum não vê outro usuário" do
    u = User.create!(username: "u2", email: "u2@example.com", password: "secret123")
    other = User.create!(username: "u3", email: "u3@example.com", password: "secret123")
    assert_not UserPolicy.new(u, other).show?
  end

  test "usuário comum vê a si mesmo" do
    u = User.create!(username: "u4", email: "u4@example.com", password: "secret123")
    assert UserPolicy.new(u, u).show?
  end
end
