# Omni — Status Consolidado do Projeto

> Snapshot: **2026-06-18**. Atualizar ao fim de cada sessão de trabalho e em toda decisão/entrega.

## Status geral
- **Fase atual:** **Fase 5 — F5.1 (render read-only de turnos de conversa)** — **implementada e validada (2026-06-18)**: turnos read-only em `/conversations/:id` via `Conversations::TurnListComponent` consumindo o `LazyLoader`. **A Fase 5 inteira NÃO está concluída** — markdown sanitizado (CV-07), triagem, dashboard e demais telas ficam para **F5.2+**. Fases anteriores: **M1** (Fundação) ✅; **M2** (domínio CRUD; migração de dados reais de domínio = N/A — RepoA inativo, domínio vazio na origem) ✅; **M3 parcial** (sync real de metadados: 1635 conversas + folders); **M4 MVP** (vínculo manual conversa↔tarefa); **pré-F5** (índice de turnos + loader lazy, `ed27143`).
- **Próxima fase:** **F5.2** (markdown sanitizado — ADR-012) e/ou ampliar redação de PII em `text`/`tool_input`; ou **F4 v1** (scorer/sugestões/auto-link). Sob autorização explícita.
- **Status geral:** Domínio CRUD completo (F2). **Conversas (metadados) com sync real**: 1635 conversas de `summaries.jsonl` (idempotente; `source_nil=0`, `workspace_hash_nil=13`, `title_nil=1067`). **F3.3** resolveu folders (`WorkspaceMap=86`, órfãos 86→3; usuário redigido `<USER>`). **Pré-F5**: índice de turnos (offsets) + loader lazy — 129.482 refs, covered 1635/1635, sem conteúdo no banco. **F5.1**: turnos read-only (texto auto-escapado + `tool_input` em `<pre>`; `personal` oculto b1; CSP restrita). **Markdown/triagem = F5.2+.** Testes: **221 runs, 776 assertions, 0 failures/errors/skips**; lint/brakeman/bundler-audit verdes.
- **Stack provisionada:** Rails 8.1.3 + PostgreSQL 16 via Docker (sem instalar nada no host; `_origem/` intocado).
- **Bloqueadores da Fase 2:** Nenhum, exceto autorização explícita do usuário.
- **Bloqueadores futuros (Fase 3):** **resolvidos (F3.0→F3.3)** — corpus; `thread_id → shard` via **ADR-018** (turnos fora); `schema_version` por-run; importer idempotente; sync real validado; folders resolvidos (**ADR-020**). Item opcional: limpar `sync_runs/sync_run_items` de auditoria no dev.
- **Ação de segurança:** dump do RepoA fora do versionamento — protegido no repo de planejamento via `.gitignore`; RepoA tratado como referência/leitura.
- **Última decisão/entrega:** **F5.1.4 — limpeza controlada dos resíduos sintéticos do DB dev (2026-06-18)**: remoção transacional **DB-only** dos artefatos de auditoria (9 refs + 3 turn_sources `/tmp` + 3 conversas `tXSS*` + 3 sync_runs `/tmp`); backup `tmp/dev_backup_pre_f514_20260618_095619.sql` (gitignored). DB dev agora fiel ao real: **conversations=1635 · turn_sources=1 · conversation_turn_refs=129482 · sync_runs=5 · conversation_links=1 · órfãs=0**; conversa real e loader `:ok` (177) preservados; nenhum arquivo alterado. Antes: **F5.1.3** (ocultar `source_file` em `/sync_runs/:id` via `safe_basename`); **F5.1.2** (consolidação documental + persistência do runtime): registro da F5.1.1, addendum ao ADR-013 (`personal` boolean + b1), padronização "Omni" e **persistência do mount `/normalized:ro`** no `.devstack/up.sh` (sem mudar comportamento de app). Antes: **F5.1.1** (`a01efbd`, fix do artefato ERB `). %>` + cor de role por allowlist) e **F5.1** (`2cc605b`, render read-only de turnos: `LazyLoader` via `Conversations::TurnListComponent`, `TURNS_PER_PAGE=50`, `personal`=b1, auto-escape, CSP restrita; validado em conversa real de 177 turnos). Pré-F5: índice de turnos + loader (`ed27143`).
- **Próxima decisão necessária:** **F5.2** (markdown sanitizado — ADR-012) e/ou ampliar redação de PII em `text`/`tool_input`; ou **F4 v1** (scorer/sugestões/auto-link).

## Semáforo por área
| Área | Status | Observação |
|---|---|---|
| Arquitetura | 🟢 Verde | ADRs aceitos; baseline congelado |
| Rails Foundation | 🟢 Verde | App Rails 8.1.3 operacional; 15 testes verdes; CI local verde |
| Banco de dados | 🟢 Verde | Postgres 16 (omni_db) + migration de `users` aplicada; domínio na F2 |
| Migração Repo A | 🟢 Verde | **M2 concluído** — domínio CRUD completo (Client+Contact+Project+Task+Demand+ConvertDemand+TimeEntry); **migração de dados reais = N/A** (RepoA inativo, domínio vazio na origem) |
| Pipeline Repo B | 🟢 Verde | Externo, estável, intocado |
| Importação de conversas | 🟡 Amarelo | **F3.0→F3.3** (sync real de metadados: 1635 conversas; `source_nil=0`/`workspace_hash_nil=13`/`title_nil=1067`). **F3.3** resolveu folders (`orphan` 86→3). **Pré-F5:** índice de turnos (offsets) + loader lazy (ADR-021) — 129.482 refs, covered 1635/1635, sem conteúdo no banco. **UI de turnos = F5.** M3 parcial |
| Vínculo conversa/tarefa | 🟡 Amarelo | **F4 MVP**: vínculo manual `conversation_links` (≤1 primário, reversível, auditável) + counters em Task. **scorer/auto-link/sugestões pendentes (v1)** |
| UI | 🟡 Amarelo | **F2.UI** (baseline) + **F3.UI.1** (console read-only) + **F4** (Vínculos) + **F5.1** (turnos read-only em `/conversations/:id`: role/ts/texto escapado + `tool_input` em `<pre>`; `TURNS_PER_PAGE=50`; `personal` oculto b1; CSP restrita). **Markdown/triagem = Fase 5.2+** |
| Testes | 🟡 Amarelo | Fundação coberta (auth/authz/CSRF/rate-limit/job); corpus de parser pendente (F3) |
| Segurança | 🟢 Verde | Devise + Pundit + CSRF nativo + rack-attack; dump fora do versionamento |
| Documentação | 🟢 Verde | Baseline + M1 registrados |
| Deploy/operação | 🟡 Amarelo | Stack dev via Docker operacional; deploy real na F7 |

## Checklist executivo
- [x] Fase 0 aprovada.
- [x] ADRs aprovados.
- [x] Modelo de dados aprovado.
- [x] DDL planejado revisado.
- [x] Corpus de teste definido (criação pendente — pré-F3).
- [x] Estratégia de sync aprovada.
- [x] Rails Foundation iniciada. **(M1 concluído — 2026-06-16)**
- [x] Domínio migrado. *(M2 concluído: CRUD completo; migração de dados reais **N/A** — RepoA inativo, domínio vazio na origem.)*
- [x] Conversas importadas. *(Metadados, F3: 1635 conversas; turnos/UI fora.)*
- [ ] Vínculos implementados. *(F4 MVP manual entregue 2026-06-17: `conversation_links` reversível/auditável + counters; scorer/auto-link/sugestões = v1.)*
- [ ] UI unificada validada.
- [ ] Testes mínimos concluídos.
- [ ] Documentação finalizada.

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
