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

---

## Addendum — 2026-06-24 (PB-017: Auth/Admin seguro, single-user)

Endurecimento da configuração do Devise para uso **single-user / somente Admin**,
sem alterar a decisão central (Devise como base de autenticação). Aplicado o
checklist **secure-auth**.

### Decisões do addendum
- **Sem cadastro público:** módulo `:registerable` removido do `User` e rotas de
  registro removidas (`devise_for :users, skip: [:registrations]`). Contas são
  criadas por **seed seguro opt-in** (`db/seeds.rb`, ENV) ou pelo console. `:recoverable`
  permanece (reset por e-mail).
- **Política de senha:** `password_length` mínimo elevado de **6 → 10** (teto 128
  mantido; sem cap baixo, sem bloquear colar).
- **Reset de senha:** `reset_password_within` reduzido de **6h → 30min** (token
  segue aleatório/single-use). `paranoid = true` (fluxo "esqueci a senha" não
  enumera contas).
- **Mailer:** `mailer_sender` deixa de ser placeholder e passa a ENV
  `OMNI_MAIL_FROM` (fallback neutro `no-reply@omni.localhost` p/ dev/test). A
  credencial de **SMTP** continua **separada** (ENV/credentials de produção),
  nunca no banco de usuário nem no código.
- **Rate limit de login:** mantido por **IP** (5/15min) e **adicionado por
  conta/e-mail** (5/15min, e-mail normalizado), defendendo contra credential
  stuffing distribuído por muitos IPs.
- **Cookies de sessão:** `SameSite=Lax` tornado explícito (já era default do
  Rails 8.1); HttpOnly por default; Secure em produção via `force_ssl` (F7.1).
- **Invalidação de sessão após troca de senha:** garantida pelo Devise (a sessão
  é validada contra o `authenticatable_salt`, derivado do `encrypted_password`;
  trocar a senha muda o salt e invalida sessões antigas) — coberto por teste.

### Custo bcrypt — RISCO RESIDUAL ACEITO (não é PASS pleno)
O custo permanece **10** (`zz_devise_overrides.rb`, compat. hashes legados RepoA —
~50–100 ms/hash), **abaixo** do alvo secure-auth de **100–300 ms**. Este item **não é
classificado como PASS pleno** contra a meta da skill: é um **risco residual aceito
pelo PO nesta fase** por compatibilidade com a decisão original do ADR-003 e pelo
contexto **single-user**. **Elevar o custo é melhoria futura** (segura via re-hash
oportunístico no login, sem quebrar hashes existentes) e fica como decisão do PO —
não alterado nesta fatia.

### Fora de escopo (PB-017)
`is_active`/inativação, multiusuário, roles avançados, `:lockable`, MFA, OAuth,
passkeys. A coluna `users.is_active` existe no schema mas **não é usada** por código
(dormente); não foi tocada.
