require "test_helper"

class CsrfProtectionTest < ActionDispatch::IntegrationTest
  test "POST sem token CSRF é rejeitado quando a proteção nativa está ativa" do
    ActionController::Base.allow_forgery_protection = true
    post user_session_path, params: { user: { email: "x@example.com", password: "secret12345" } }
    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
