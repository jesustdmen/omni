require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "válido com atributos mínimos" do
    u = User.new(username: "jt", email: "jt@example.com", password: "secret12345")
    assert u.valid?
  end

  test "exige username" do
    u = User.new(email: "a@example.com", password: "secret12345")
    assert_not u.valid?
    assert u.errors[:username].any?
  end

  test "username é único" do
    User.create!(username: "dup", email: "a@example.com", password: "secret12345")
    u = User.new(username: "dup", email: "b@example.com", password: "secret12345")
    assert_not u.valid?
  end

  test "role default é user e não é admin" do
    u = User.create!(username: "u", email: "u@example.com", password: "secret12345")
    assert_equal "user", u.role
    assert_not u.admin?
  end

  test "role inválido é rejeitado" do
    u = User.new(username: "u2", email: "u2@example.com", password: "secret12345", role: "superhero")
    assert_not u.valid?
  end

  # PB-017 — política de senha (Devise :validatable, password_length 10..128).
  test "senha com menos de 10 caracteres é rejeitada" do
    u = User.new(username: "short", email: "short@example.com", password: "abc12345") # 8 chars
    assert_not u.valid?
    assert u.errors[:password].any?, "deveria invalidar senha curta"
  end

  test "senha com exatamente 10 caracteres é aceita" do
    u = User.new(username: "ten", email: "ten@example.com", password: "abcde12345") # 10 chars
    assert u.valid?, u.errors.full_messages.to_sentence
  end

  test "não tem :registerable habilitado (sem cadastro público)" do
    assert_not User.devise_modules.include?(:registerable),
               ":registerable deve estar removido (PB-017)"
    assert User.devise_modules.include?(:recoverable), ":recoverable deve permanecer (reset por e-mail)"
  end
end
