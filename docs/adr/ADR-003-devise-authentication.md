# ADR-003 — Devise para autenticação

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O Repo A usa sessão (express-session), bcrypt rounds=10, role admin/user, is_active, rate-limit de login 5/15min e delay anti-timing. O hash bcrypt é compatível com Devise (a confirmar formato `$2b$10$...` nos dados reais).

## Decisão
Devise (database_authenticatable + sessão), migrando `password_hash` → `encrypted_password`.
- Manter compatibilidade com o custo bcrypt atual (aparentemente 10).
- Prever re-hash oportunístico no próximo login, se viável.
- Não bloquear o login dos usuários migrados.

## Alternativas consideradas
- Autenticação própria (igual hoje) — reimplementar segurança madura sem ganho.
- has_secure_password puro — viável, mas Devise traz recoverable/lockable de graça.

## Consequências positivas
- Migração de senha transparente (bcrypt↔bcrypt).
- Recoverable/lockable disponíveis.

## Consequências negativas
- Peso/"mágica" do Devise.

## Riscos
- Diferença de custo (Repo A=10, Devise default=12): manter 10 na migração e re-hash no login.

## Critérios de aceite
- Usuário migrado faz login com a senha antiga sem reset.

## O que NÃO fazer
- Não re-hashear senhas em massa (quebra login). Não inventar auth própria.

## Validação futura
- Teste real de login com hash migrado durante a Fase 1.
