# Omni — Status Consolidado do Projeto

> Snapshot: **2026-06-18**. Atualizar ao fim de cada sessão de trabalho e em toda decisão/entrega.

## Status geral
- **Fase atual:** **Fase 5 — MVP interno CONCLUÍDO (2026-06-19)**. Loop interno completo e validado (7 smokes): listar/filtrar conversas por vínculo (F5.4), abrir conversa e renderizar turnos com segurança (F5.1) — **PII redigida** (F5.1.5) + **markdown sanitizado** (F5.2) + `tool_input` em `<pre>`; **criar tarefa a partir da conversa** (F5.3), vincular conversa↔tarefa e ver o vínculo dos dois lados (F4), navegar a task por âncoras (F5.5). **Pendências restantes são roadmap/v1** (não bloqueiam uso interno). Fases anteriores: **M1** (Fundação) ✅; **M2** (domínio CRUD; migração de domínio = N/A — RepoA inativo) ✅; **M3 MVP de metadados** (sync real 1635 conversas + folders + índice/loader lazy); **M4 MVP** (vínculo manual).
- **Próxima fase (a decidir, sob autorização):** **F4 v1** (scorer/sugestões/auto-link); ou continuidade da UI (UI-09 Ctrl+L, UI-01 dashboard, UI-04 aba Conversas rica — roadmap/v1); ou **fundação de produção (F7)**.
- **Status geral:** Domínio CRUD completo (F2). **Conversas (metadados) com sync real**: 1635 conversas de `summaries.jsonl` (idempotente; `source_nil=0`, `workspace_hash_nil=13`, `title_nil=1067`). **F3.3** resolveu folders (`WorkspaceMap=86`, órfãos 86→3; usuário redigido `<USER>`). **Pré-F5**: índice de turnos (offsets) + loader lazy — 129.482 refs, covered 1635/1635, sem conteúdo no banco. **F5 MVP**: render read-only seguro + PII + markdown sanitizado + lista acionável + criar/vincular tarefa + navegação por âncoras. Testes: **274 runs, 1068 assertions, 0 failures/errors/skips**; rubocop 132/0; brakeman 0; bundler-audit 0.
- **Stack provisionada:** Rails 8.1.3 + PostgreSQL 16 via Docker (sem instalar nada no host; `_origem/` intocado).
- **Bloqueadores da Fase 2:** Nenhum, exceto autorização explícita do usuário.
- **Bloqueadores futuros (Fase 3):** **resolvidos (F3.0→F3.3)** — corpus; `thread_id → shard` via **ADR-018** (turnos fora); `schema_version` por-run; importer idempotente; sync real validado; folders resolvidos (**ADR-020**). Item opcional: limpar `sync_runs/sync_run_items` de auditoria no dev.
- **Ação de segurança:** dump do RepoA fora do versionamento — protegido no repo de planejamento via `.gitignore`; RepoA tratado como referência/leitura.
- **Trilha ativa: Produto Operacional (replanejamento, 2026-06-19).** F7.2 **pausada** até o gate operacional (ver `PRODUCT_BACKLOG.md §5`). Entregues: **PB-001** auditoria (`3037a00`) + **PB-002** revisão da matriz + **PB-003a** controle de tempo (timer start/stop + duração em segundos + paralelismo configurável + histórico operacional, `d11f099`, **aceite manual do PO** no fluxo principal). **PB-003 segue PARCIAL** — PB-003b (agrupamento/subtotal por dia) e PB-003c (retroativo assistido) **pendentes**. **Próximas decisões do PO:** PB-003b/PB-003c · busca/filtros/paginação das listas (PB-004/005/006) · **PB-013 UX de navegação/contexto** · **PB-014 código legível de tarefa**. Governança em `PRODUCT_BACKLOG.md`/`PRODUCT_GAP_REVIEW.md`.
- **Última decisão/entrega (código):** **PB-003a — controle de tempo operacional (2026-06-19, `d11f099`)**: `time_entries` ganha **timer start/stop** (`TaskTimersController`/`TimeEntriesController#stop`), **`duration` calculado em segundos** (`stop!`), **`ALLOW_PARALLEL_RUNNING_TIMERS`** (default true), **índice único parcial** (1 timer aberto/tarefa) + validação, e **"Histórico de Apontamentos"** com ações inline (ver/editar/excluir/parar; ícones lucide + cores). Suíte **294/1151/0**; rubocop 135/0; brakeman 0. PB-003b/PB-003c pendentes. Antes: **F7.1 — endurecimento de produção + admin seed**: `production.rb` por ENV (`force_ssl`/`assume_ssl`/`config.hosts`/mailer host; `/up` fora do redirect; default seguro, sem domínio hardcoded); `db/seeds.rb` admin **opt-in/idempotente** (`OMNI_SEED_ADMIN` + `OMNI_ADMIN_*`; sem senha padrão/sem logar senha; promove sem trocar senha; no-op sem flag → CI verde). Sem schema/Solid/Kamal/Dockerfile/credentials. Suíte **279/1087/0**; rubocop 133/0; brakeman 0; bundler-audit 0. Antes: **F5 MVP interno concluído** (F5.1→F5.5). Antes: **F5.5 — usabilidade da task: navegação por âncoras (2026-06-19)**: abas cosméticas de `tasks/show` viram **links de âncora honestos (sem JS)** (`#tab-detalhes`/`#tab-time`/`#tab-conversas`); "Conversas (N)" mostra contagem de vínculos; "Histórico"/"Demanda" permanecem "em breve" sem `href`; CSS escopado (`scroll-margin-top`, realce `:target`). **Sem abas dinâmicas JS** (seguem roadmap). Suíte **274/1068/0**; rubocop 132/0; brakeman 0; bundler-audit 0. Antes: **F5.4 — lista de conversas acionável / status de vínculo (CV-04, `9537eac`)**: `/conversations` com coluna **Vínculo** + filtro `link` (`none`/`primary`/`mention`); eager loading sem N+1. Antes: **F5.3 — criar tarefa a partir da conversa (UI-10, `c104203`)**: `ConversationTasksController` cria `Task` + `ConversationLink` `primary`/`manual` **em transação** (rollback sem órfã); ação oculta quando já há `primary`. Antes: **F5.2 — markdown sanitizado no render** (`f3075e0`): `text` vira **markdown (GFM) → HTML sanitizado** via `ConversationTurns::MarkdownRenderer` (`commonmarker 2.8.2` seguro + `SafeListSanitizer` allowlist + hardening de links); `tool_input` em `<pre>`; PII antes do markdown; `html_safe` só no renderer. Antes: **F5.1.5 — redação de PII em `text`/`tool_input` (`821f495`)**: `ConversationTurns::PiiRedactor` (conservador/idempotente) cobrindo e-mail/Bearer/`token|api_key|secret|password|access_token|refresh_token`/paths `Users|home` (Unix/Windows/`file://`) → `<EMAIL>`/`<SECRET>`/`<USER>`. Antes: **F5.1.4 — limpeza DB-only dos resíduos sintéticos** (9 refs + 3 turn_sources `/tmp` + 3 conversas `tXSS*` + 3 sync_runs `/tmp`; backup `tmp/dev_backup_pre_f514_20260618_095619.sql` gitignored). DB dev fiel ao real: **conversations=1635 · turn_sources=1 · conversation_turn_refs=129482 · sync_runs=5 · conversation_links=1 · órfãs=0**; conversa real e loader `:ok` (177) preservados; nenhum arquivo alterado. Antes: **F5.1.3** (ocultar `source_file` em `/sync_runs/:id` via `safe_basename`); **F5.1.2** (consolidação documental + persistência do runtime): registro da F5.1.1, addendum ao ADR-013 (`personal` boolean + b1), padronização "Omni" e **persistência do mount `/normalized:ro`** no `.devstack/up.sh` (sem mudar comportamento de app). Antes: **F5.1.1** (`a01efbd`, fix do artefato ERB `). %>` + cor de role por allowlist) e **F5.1** (`2cc605b`, render read-only de turnos: `LazyLoader` via `Conversations::TurnListComponent`, `TURNS_PER_PAGE=50`, `personal`=b1, auto-escape, CSP restrita; validado em conversa real de 177 turnos). Pré-F5: índice de turnos + loader (`ed27143`).
- **Próxima decisão necessária:** **Produto Operacional** — fechar PB-003 com **PB-003b** (agrupamento/subtotal por dia) e **PB-003c** (retroativo assistido); ou a camada de **busca/filtros/paginação** das listas (PB-004/005/006); ou **PB-013** (UX navegação/contexto) / **PB-014** (código legível de tarefa). **F7.2 retoma só após o gate de produto (GP-01..07).** *(PB-003a entregue/aceita; F7.1 entregue; F5 MVP interno concluído.)*

## Semáforo por área
| Área | Status | Observação |
|---|---|---|
| Arquitetura | 🟢 Verde | ADRs aceitos; baseline congelado |
| Rails Foundation | 🟢 Verde | App Rails 8.1.3 operacional; 15 testes verdes; CI local verde |
| Banco de dados | 🟢 Verde | Postgres 16 (omni_db) + migration de `users` aplicada; domínio na F2 |
| Migração Repo A | 🟢 Verde | **M2 concluído** — domínio CRUD completo (Client+Contact+Project+Task+Demand+ConvertDemand+TimeEntry); **migração de dados reais = N/A** (RepoA inativo, domínio vazio na origem) |
| Pipeline Repo B | 🟢 Verde | Externo, estável, intocado |
| Importação de conversas | 🟢 Verde (MVP metadados) | **M3 MVP de metadados CONCLUÍDO:** sync real idempotente (1635 conversas; `source_nil=0`/`workspace_hash_nil=13`/`title_nil=1067`), folders (`orphan` 86→3), índice de turnos + loader lazy (ADR-021; 129.482 refs, covered 1635/1635, sem conteúdo no banco). **Pendências → roadmap:** OP-01/OP-03, CV-03, CV-10. UI rica de turnos = F5 |
| Vínculo conversa/tarefa | 🟢 Verde (MVP manual) | **M4 MVP manual CONCLUÍDO:** `conversation_links` (≤1 primário, reversível, auditável) + counters transacionais (LK-01/02/03/07/08). **Pendências → v1:** scorer/sugestões/auto-link (LK-04/05), aceite em lote (LK-06), `time_entry_id` |
| UI | 🟡 Amarelo | **F2.UI** (baseline) + **F3.UI.1** (console read-only) + **F4** (Vínculos) + **F5.1** (turnos read-only em `/conversations/:id`: role/ts/texto escapado + `tool_input` em `<pre>`; `TURNS_PER_PAGE=50`; `personal` oculto b1; CSP restrita). **Markdown/triagem = Fase 5.2+** |
| Testes | 🟡 Amarelo | Suíte verde **225/811/0**; corpus sintético criado (`test/fixtures/normalized_corpus/`); cobertura por controller/serviço/policy. Lacunas: teste de PII em `text`/`tool_input`, teste de filtro de log, SimpleCov |
| Segurança | 🟢 Verde | Devise + Pundit + CSRF nativo + rack-attack + CSP restrita; dump fora do versionamento; **render de turnos com auto-escape + redação de PII (F5.1.5)** |
| Documentação | 🟢 Verde | Baseline + M1 registrados |
| Deploy/operação | 🔴 Vermelho (prod não exercida) | Dev reproduzível (`.devstack/up.sh`); **produção NUNCA exercida**. F7.1 endureceu `production.rb` (TLS/hosts/mailer por ENV) + admin seed. Restam: Kamal/`config/deploy.yml`, schemas Solid cache/cable, worker de jobs, `/normalized`-em-prod, runbook backup/restore/rollback. Ver "Readiness de produção (F7)" abaixo |

## Checklist executivo
- [x] Fase 0 aprovada.
- [x] ADRs aprovados.
- [x] Modelo de dados aprovado.
- [x] DDL planejado revisado.
- [x] Corpus de teste definido e **criado** (`test/fixtures/normalized_corpus/`; usado nos testes).
- [x] Estratégia de sync aprovada.
- [x] Rails Foundation iniciada. **(M1 concluído — 2026-06-16)**
- [x] Domínio migrado. *(M2 concluído: CRUD completo; migração de dados reais **N/A** — RepoA inativo, domínio vazio na origem.)*
- [x] Conversas importadas. *(Metadados, F3: 1635 conversas; turnos/UI fora.)*
- [x] Vínculos implementados. *(M4 MVP manual concluído: `conversation_links` reversível/auditável + counters; scorer/auto-link/sugestões/aceite-lote/`time_entry_id` = v1/roadmap.)*
- [ ] UI unificada validada. *(F5.1 read-only entregue; Fase 5 aberta — F5.2 markdown/UI-01/04/09/10/busca/triagem pendentes.)*
- [ ] Testes mínimos concluídos.
- [ ] Documentação finalizada.

## Readiness de produção (F7) — diagnóstico pós-F5.1.4
> **App sólido; produção NUNCA exercida.** Apto a **MVP interno single-tenant apenas após a fundação F7**. **Exposição externa/multi-tenant NÃO recomendada** sem: F7 completa + isolamento por owner/tenant (hoje ADR-014 = domínio compartilhado) + redação de PII em `text`/`tool_input`.

**Resolvido na F7.1 (2026-06-19):** `production.rb` endurecido por ENV (`force_ssl`/`assume_ssl`/`config.hosts`/mailer host) com `/up` fora do redirect; **admin seed** opt-in/idempotente (`db/seeds.rb`) seguro; **redação de PII em `text`/`tool_input`** (entregue antes na F5.1.5).

**Bloqueadores (F7) restantes antes de subir produção:**
- Schemas **Solid cache/queue/cable** ausentes (só `db/queue_schema.rb`) → `db:prepare` incompleto; `cache_store` não aponta `:solid_cache_store`.
- `cable.yml` de produção ainda em **Redis** (não `solid_cable`).
- **Kamal/deploy ausente** (`config/deploy.yml`/`.kamal/`); sem TLS/reverse-proxy/restart declarados.
- **Worker de jobs** (Solid Queue) não definido (`SOLID_QUEUE_IN_PUMA` ou `bin/jobs`).
- **`/normalized` em produção indefinido** (sem origem/volume `:ro` → conversas `:stale`).
- **Pipeline Python** sem topologia de produção (onde roda / como entrega `sessions.jsonl` / cadência de reindex `sync:turn_refs`).
- **Backup/restore/rollback** de produção pendentes (runbook).

**Não bloqueante (corrigir na F7):** entrada órfã `001 NO FILE` em `schema_migrations`; `time_zone`/`i18n.default_locale` nos defaults (UTC/:en) apesar da UI pt-BR.

**OK (já maduro):** `master.key` gitignored/nunca commitado + `credentials.yml.enc`; `filter_parameter_logging` robusto; CSP restrita; rack-attack; healthcheck `/up` + páginas de erro; Dockerfile multi-stage não-root; XSS/Pundit/CSRF cobertos por teste.

## Fronteiras do projeto
- **`_origem/` e `_mockup/` são SOMENTE LEITURA** (referência); o produto é construído do zero em `app/`.
- `_origem/_repoa` e `_origem/_repob` = referência de domínio/pipeline. `_mockup` = referência visual/de fluxo.
- Proibido copiar código/componentes/assets/arquivos das referências sem aprovação explícita (gatilho de parada).
- **Topologia (consolidada — ADR-019):** `app/` é o **repositório Git único** (produto + governança em `app/docs/`; toolchain em `app/.devstack/`). A raiz `c:\Sandbox\_omni` é apenas pasta local de trabalho/histórico (seu `.git` antigo é mantido como arquivo, sem novos commits). `_origem/` e `_mockup/` seguem fora do repo.
- Regra completa: ver [CONSTRAINTS.md](CONSTRAINTS.md).

## Governança da documentação
- **Ordem de atualização:** ARCHITECTURE_DECISIONS_INDEX → ROADMAP → MIGRATION_PLAN → FEATURE_MATRIX → DELIVERY_LOG → PROJECT_STATUS (sempre por último).
- **A cada entrega:** DELIVERY_LOG + FEATURE_MATRIX + PROJECT_STATUS (e ROADMAP se fechou marco).
- **A cada decisão arquitetural:** novo `docs/adr/ADR-NNN-*.md` + ARCHITECTURE_DECISIONS_INDEX + PROJECT_STATUS.
- **A cada mudança de escopo:** FEATURE_MATRIX + ROADMAP + PROJECT_STATUS (e MIGRATION_PLAN se afeta dados/estratégia).
