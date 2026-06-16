require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  test "bloqueia após 5 tentativas de login em 15 min (rack-attack)" do
    5.times do
      post user_session_path, params: { user: { email: "no@example.com", password: "wrong" } }
      assert_not_equal 429, response.status
    end
    post user_session_path, params: { user: { email: "no@example.com", password: "wrong" } }
    assert_response :too_many_requests
  end
end
