require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "redireciona para login quando não autenticado" do
    get root_path
    assert_redirected_to new_user_session_path
  end

  test "login válido dá acesso ao dashboard" do
    User.create!(username: "jt", email: "jt@example.com", password: "secret12345", role: "admin")
    post user_session_path, params: { user: { email: "jt@example.com", password: "secret12345" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "login inválido não autentica" do
    post user_session_path, params: { user: { email: "x@example.com", password: "wrongpass123" } }
    assert_response :unprocessable_entity
  end

  test "login com senha errada de conta existente não autentica (mensagem genérica)" do
    User.create!(username: "jt", email: "jt@example.com", password: "secret12345", role: "admin")
    post user_session_path, params: { user: { email: "jt@example.com", password: "errada-pass-9" } }
    assert_response :unprocessable_entity
    # Mensagem genérica do Devise — não revela se foi o e-mail ou a senha que errou.
    assert_match(/Invalid Email or password|E-mail ou senha inválid/i, response.body)
  end

  # PB-017 — cadastro público desabilitado (single-user/somente Admin).
  # Em teste de integração, uma rota inexistente resulta em 404 (o RoutingError
  # é capturado pelo middleware de rotas), não em exceção propagada.
  test "GET /users/sign_up não é rota válida (404)" do
    get "/users/sign_up"
    assert_response :not_found
  end

  test "POST /users (criar conta) não é rota válida e não cria usuário" do
    assert_no_difference("User.count") do
      post "/users", params: { user: { email: "intruso@example.com", username: "intruso", password: "secret12345" } }
    end
    assert_response :not_found
  end

  test "helpers de rota de registro não estão definidos (registrations skip)" do
    helpers = Rails.application.routes.url_helpers
    assert_not helpers.respond_to?(:new_user_registration_path),
               "new_user_registration_path não deveria existir"
    assert_not helpers.respond_to?(:user_registration_path),
               "user_registration_path não deveria existir"
  end
end
