require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "redireciona para login quando não autenticado" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "login válido dá acesso ao dashboard" do
    User.create!(username: "jt", email: "jt@example.com", password: "secret123", role: "admin")
    post user_session_path, params: { user: { email: "jt@example.com", password: "secret123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "login inválido não autentica" do
    post user_session_path, params: { user: { email: "x@example.com", password: "wrong" } }
    assert_response :unprocessable_entity
  end
end
