# Rate limiting de borda (Fase 1).
class Rack::Attack
  # Contador próprio (independe de Rails.cache, que é :null_store em test).
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Limite global: 300 requisições / 15 min por IP (ignora assets e health check).
  throttle("req/ip", limit: 300, period: 15.minutes) do |req|
    req.ip unless req.path.start_with?("/assets") || req.path == "/up"
  end

  # Login: 5 tentativas / 15 min por IP no POST de sessão (anti brute force).
  throttle("logins/ip", limit: 5, period: 15.minutes) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # PB-017 — Login por CONTA/E-MAIL: 5 tentativas / 15 min para o MESMO e-mail,
  # independente do IP (anti credential-stuffing distribuído por muitos IPs).
  # Lê o e-mail do corpo do POST de sessão; normaliza (downcase/strip) para
  # contar variações como a mesma conta. Não dispara quando o e-mail está ausente.
  throttle("logins/email", limit: 5, period: 15.minutes) do |req|
    if req.path == "/users/sign_in" && req.post?
      email = req.params.dig("user", "email").to_s.downcase.strip
      email.presence # discriminador = e-mail; nil/"" não conta (sem falso-positivo)
    end
  end

  self.throttled_responder = lambda do |_req|
    [ 429, { "content-type" => "text/plain" }, [ "Muitas requisições. Tente novamente mais tarde.\n" ] ]
  end
end

Rails.application.config.middleware.use Rack::Attack
