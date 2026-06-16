require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "válido com atributos mínimos" do
    u = User.new(username: "jt", email: "jt@example.com", password: "secret123")
    assert u.valid?
  end

  test "exige username" do
    u = User.new(email: "a@example.com", password: "secret123")
    assert_not u.valid?
    assert u.errors[:username].any?
  end

  test "username é único" do
    User.create!(username: "dup", email: "a@example.com", password: "secret123")
    u = User.new(username: "dup", email: "b@example.com", password: "secret123")
    assert_not u.valid?
  end

  test "role default é user e não é admin" do
    u = User.create!(username: "u", email: "u@example.com", password: "secret123")
    assert_equal "user", u.role
    assert_not u.admin?
  end

  test "role inválido é rejeitado" do
    u = User.new(username: "u2", email: "u2@example.com", password: "secret123", role: "superhero")
    assert_not u.valid?
  end
end
