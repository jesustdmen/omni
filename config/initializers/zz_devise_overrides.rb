# ADR-003 — custo bcrypt ~10 (compatível com hashes legados do RepoA).
# Em test usamos custo 1 para velocidade. Re-hash oportunístico vive no model User.
# Carrega após config/initializers/devise.rb (ordem alfabética garante 'zz_').
Devise.stretches = Rails.env.test? ? 1 : 10
