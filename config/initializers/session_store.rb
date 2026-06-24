# PB-017 — Endurecimento de cookies de sessão (auditoria secure-auth).
#
# HttpOnly e Secure já são garantidos pelo Rails:
#   - HttpOnly: o cookie de sessão é HttpOnly por padrão (JS não lê o session id).
#   - Secure  : em produção, `config.force_ssl = true` marca os cookies como Secure
#               (enviados só por HTTPS). Em dev/test não se força Secure (sem TLS).
#
# SameSite já é `:lax` por `config.load_defaults 8.1`. Tornamos explícito aqui
# para registrar a intenção e blindar contra mudança futura de default. `:lax`
# (em vez de `:strict`) preserva o fluxo de link de reset de senha por e-mail —
# a navegação top-level a partir do link mantém a usabilidade — enquanto ainda
# barra envio de cookie em requisições cross-site de terceiros (anti-CSRF, em
# camadas com o token CSRF nativo do Rails).
Rails.application.config.action_dispatch.cookies_same_site_protection = :lax
