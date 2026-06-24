require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  # PB-017 — o login é limitado por IP E por conta/e-mail (rack-attack).
  # Variamos REMOTE_ADDR para isolar cada throttle de forma determinística.

  test "bloqueia após 5 tentativas de login por IP em 15 min (logins/ip)" do
    # Mesmo IP, e-mails diferentes → só o throttle por IP pode disparar.
    5.times do |i|
      post user_session_path,
           params: { user: { email: "u#{i}@example.com", password: "wrongpass123" } },
           env: { "REMOTE_ADDR" => "10.0.0.1" }
      assert_not_equal 429, response.status
    end
    post user_session_path,
         params: { user: { email: "u6@example.com", password: "wrongpass123" } },
         env: { "REMOTE_ADDR" => "10.0.0.1" }
    assert_response :too_many_requests
  end

  test "bloqueia após 5 tentativas para o MESMO e-mail mesmo variando o IP (logins/email)" do
    # IPs diferentes a cada request → o throttle por IP nunca acumula;
    # só o throttle por e-mail pode disparar (anti credential-stuffing distribuído).
    5.times do |i|
      post user_session_path,
           params: { user: { email: "alvo@example.com", password: "wrongpass123" } },
           env: { "REMOTE_ADDR" => "10.1.0.#{i + 1}" }
      assert_not_equal 429, response.status
    end
    post user_session_path,
         params: { user: { email: "alvo@example.com", password: "wrongpass123" } },
         env: { "REMOTE_ADDR" => "10.1.0.99" }
    assert_response :too_many_requests
  end

  test "e-mail é normalizado: variações de caixa/espaço contam como a mesma conta" do
    variants = [ "Alvo@Example.com", " alvo@example.com ", "ALVO@EXAMPLE.COM", "alvo@example.com", "AlVo@ExAmPlE.com" ]
    variants.each_with_index do |email, i|
      post user_session_path,
           params: { user: { email: email, password: "wrongpass123" } },
           env: { "REMOTE_ADDR" => "10.2.0.#{i + 1}" }
      assert_not_equal 429, response.status
    end
    post user_session_path,
         params: { user: { email: "alvo@example.com", password: "wrongpass123" } },
         env: { "REMOTE_ADDR" => "10.2.0.99" }
    assert_response :too_many_requests
  end

  test "login sem e-mail não dispara o throttle por conta (sem falso-positivo)" do
    # Sem e-mail no corpo, o discriminador por e-mail é nil → não conta.
    # Variamos IP para o throttle por IP também não interferir.
    7.times do |i|
      post user_session_path,
           params: { user: { password: "wrongpass123" } },
           env: { "REMOTE_ADDR" => "10.3.0.#{i + 1}" }
      assert_not_equal 429, response.status
    end
  end
end
