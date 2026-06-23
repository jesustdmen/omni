# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# F5.1 — CSP restrita como defesa em profundidade contra XSS (ADR-012).
# A defesa primária é o auto-escape do ERB; a CSP é a 2ª barreira caso algo regrida.
# Nonce habilitado para o importmap (script inline) continuar funcionando.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    # PB-006/ADR-022 (addendum 2026-06-23) — a consulta de CNPJ é feita no navegador
    # (fetch direto na BrasilAPI, usando o IP do usuário). connect-src permite ESSE
    # host fixo (allowlist), além de :self; nenhuma outra origem externa é liberada.
    policy.connect_src :self, "https://brasilapi.com.br"
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.frame_ancestors :none
  end

  # Nonce por sessão para o importmap (e quaisquer scripts/styles permitidos).
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_nonce_auto = true
end
