# Omni — Decisões de contrato da Fase 7 (Readiness de produção / operação)

> Fundação para operar o Omni fora do ciclo dev, em **recortes pequenos**. Nada de
> deploy real nesta fase sem autorização. Base: diagnóstico "Readiness de produção (F7)"
> em [`PROJECT_STATUS.md`](PROJECT_STATUS.md). Cada recorte tem **gate separado** quando
> tocar auth/seed, schema, deploy, credenciais.

## Sequência planejada (recortes)

- **F7.1 — Endurecimento de produção (config) + admin seed** — ENTREGUE 2026-06-19.
- **F7.2 — Solid trifecta** (cache/cable schemas + `cache_store` + decidir cable Redis×solid_cable). *(gate de schema)*
- **F7.3 — Worker/runtime de jobs** (`SOLID_QUEUE_IN_PUMA` × `bin/jobs`).
- **F7.4 — Deploy (Kamal)** (`config/deploy.yml` + `.kamal/secrets`). *(sem executar deploy)*
- **F7.5 — `/normalized` em produção + cadência de reindex** (volume `:ro`; runbook `sync:*`). **Parcial:** a ORIGEM agora é o **pipeline nativo** (`app/pipeline/output/normalized`, F7.7) — não mais o RepoB. Em **dev** o mount já vem do nativo. **Aberto p/ produção:** onde o host Windows roda a coleta e como o volume `:ro` é entregue ao container em deploy.
- **F7.6 — Runbook operacional** (backup/restore/rollback + checklist de primeiro deploy).
- **F7.7 — Pipeline NATIVO de coleta/normalização — ✅ INTERNALIZADO (2026-06-29; ADR-011 addendum 2026-06-29).** O pipeline produtivo (ingest→normalize + `lib`) foi internalizado **verbatim** em **`app/pipeline/`** com entrypoint `run_collect.py` (sem report). **RepoB deixa de ser runtime**: o agente roda `app/pipeline/run_collect.py` e o mount `/normalized` vem de `app/pipeline/output/normalized` (output gitignored). **A/B byte-a-byte** (sessions/summaries SHA256 idênticos) e validação Omni (import+turn_refs, covered 1665/1665) confirmados. Contrato produtivo: `summaries.jsonl`+`sessions.jsonl`+`shards/*`; `session_titles.json`/`tags.json` são do viewer (fora). **Pendências de produção (seguem F7.2–F7.6):** Solid trifecta, worker no deploy, Kamal, runbook backup/restore/rollback, SMTP — e empacotamento/operação do pipeline nativo em produção (onde o host Windows roda a coleta). **PB-016 agora é nativa em dev/local; produção plena depende de F7.2–F7.6.**

## F7.1 — Endurecimento de produção + admin seed (ENTREGUE 2026-06-19)

Recorte de config + seed, **sem** schema/migration/Solid/Kamal/Dockerfile/credentials.

### `config/environments/production.rb` (tudo por ENV; sem domínio/segredo hardcoded)
- **TLS:** `config.assume_ssl` ← `APP_ASSUME_SSL` (default `true` — TLS termina em proxy/Thruster); `config.force_ssl` ← `APP_FORCE_SSL` (default `true`). `config.ssl_options` exclui `/up` do redirect (healthcheck).
- **Host/DNS-rebinding:** `config.hosts += APP_HOSTS` (lista por vírgula; aplica só não-vazios após `strip`). Sem `APP_HOSTS` → **não restringe** (evita lockout em boot/healthcheck). `/up` fora da host authorization quando há hosts. **Produção real DEVE definir `APP_HOSTS`.**
- **Mailer:** `default_url_options = { host: APP_HOST||"localhost", protocol: APP_PROTOCOL||"https" }`. **SMTP não configurado** nesta fatia.
- **Parser booleano:** `ActiveModel::Type::Boolean` (aceita `true/1/yes/on`).

### `db/seeds.rb` — admin inicial OPT-IN/idempotente
- Opt-in por `OMNI_SEED_ADMIN` (sem a flag → **no-op seguro**, mantém `db:seed:replant` do CI verde).
- Flag ativa exige `OMNI_ADMIN_EMAIL` + `OMNI_ADMIN_PASSWORD` (senão **raise claro**, nenhum usuário parcial). `OMNI_ADMIN_USERNAME` default `"admin"`.
- **Idempotência:** busca por e-mail; não existe → cria `role: "admin"`; já existe → **não duplica**, **não troca senha**, apenas **promove a admin** se ainda não for. Colisão de username → erro explícito (resolver via `OMNI_ADMIN_USERNAME`).
- **Segurança:** sem senha padrão; senha **nunca** logada (e `filter_parameters` cobre `passw`). Usa o `role` já existente no model `User` (ADR-003; `ROLES = %w[user admin]`) — **sem alterar model/policies**. Autorização efetiva segue ADR-014 (domínio compartilhado).

### ENV vars (F7.1)
| ENV | Uso | Default |
|---|---|---|
| `APP_FORCE_SSL` | `config.force_ssl` | `true` |
| `APP_ASSUME_SSL` | `config.assume_ssl` (TLS no proxy) | `true` |
| `APP_HOSTS` | `config.hosts` (lista por vírgula) | vazio = sem restrição |
| `APP_HOST` | host de links/mailer | `localhost` |
| `APP_PROTOCOL` | protocolo de links/mailer | `https` |
| `OMNI_SEED_ADMIN` | opt-in do seed admin | ausente = no-op |
| `OMNI_ADMIN_EMAIL` | e-mail do admin | (obrigatória se flag) |
| `OMNI_ADMIN_PASSWORD` | senha do admin | (obrigatória se flag) |
| `OMNI_ADMIN_USERNAME` | username do admin | `admin` |

### Validação
- Testes: `test/seeds_admin_test.rb` (no-op sem flag; raise sem e-mail/senha; cria admin; idempotente; promove sem trocar senha). Suíte **279/1087/0**; rubocop 133/0; brakeman 0; bundler-audit 0.
- `db:seed:replant` (RAILS_ENV=test, sem flag) → no-op (users=0).
- Smoke de config (`SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails runner`, sem servidor/segredo): defaults → `force_ssl/assume_ssl=true`, `hosts=[]`, mailer `localhost/https`; com ENV → flags `false`, `hosts=[omni.example.com, www.omni.example.com]`, mailer `omni.example.com`.

### Fora desta fatia (segue F7.2+)
Solid cache/cable schemas, `cache_store=:solid_cache_store`, cable Redis×solid_cable, worker no deploy, Kamal, `/normalized` em prod, SMTP, backup/restore/rollback, pipeline Python.
