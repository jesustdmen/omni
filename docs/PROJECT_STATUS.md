# Omni/Continuity — Status Consolidado do Projeto

> Snapshot: **2026-06-17**. Atualizar ao fim de cada sessão de trabalho e em toda decisão/entrega.

## Status geral
- **Fase atual:** Fase 2 — **CONCLUÍDA (2026-06-17)**: domínio CRUD completo (F2.1–F2.4 + F2.5 TimeEntry). M1 fechado. **F2.UI — baseline visual hi-fi provisório aprovado** (apresentação; UI final = Fase 5). **M2 CONCLUÍDO por modelagem/CRUD; migração de dados reais de domínio = N/A** — o RepoA estava **inativo** e o snapshot real (`postgres-volume-snapshot-20260328.tgz`, DB `app_v2`) tem o **domínio vazio** (clients/contacts/projects/tasks/demands/time_entries = 0; só 2 usuários de teste, **não migrados**). Não há massa histórica a importar.
- **Próxima fase:** Fase 3 — sync de conversas normalizadas. **F3.0→F3.3 CONCLUÍDAS e PUBLICADAS (2026-06-17, até commit `58f317c`)**: sync real de metadados (1635 conversas) + correção de merge + resolução de folders (órfãos 86→3). Próximo (sob autorização): **Fase 4** (vínculo conversa↔tarefa) ou uma **tela read-only de Conversas/Sync** para validação visual.
- **Status geral:** Domínio CRUD completo (F2). **Conversas (metadados) com sync real entregue**: 1635 conversas de `summaries.jsonl` (idempotente); `source_nil=0`, `workspace_hash_nil=13`, `title_nil=1067` (limitação do dado). **F3.3 resolveu folders de workspace** (exceção controlada ao ADR-008, read-only): `WorkspaceMap=86`, **órfãos 86 → 3** (83 resolvidos; usuário redigido `<USER>`). **Turnos/UI/vínculo conversa↔tarefa FORA** (ADR-018; F4/F5). **M3 parcial** (metadados+folders; módulo completo de conversas não). 162 testes verdes; lint/brakeman/bundler-audit verdes.
- **Stack provisionada:** Rails 8.1.3 + PostgreSQL 16 via Docker (sem instalar nada no host; `_origem/` intocado).
- **Bloqueadores da Fase 2:** Nenhum, exceto autorização explícita do usuário.
- **Bloqueadores futuros (Fase 3):** **resolvidos (F3.0→F3.3)** — corpus; `thread_id → shard` via **ADR-018** (turnos fora); `schema_version` por-run; importer idempotente; sync real validado; folders resolvidos (**ADR-020**). Item opcional: limpar `sync_runs/sync_run_items` de auditoria no dev.
- **Ação de segurança:** dump do RepoA fora do versionamento — protegido no repo de planejamento via `.gitignore`; RepoA tratado como referência/leitura.
- **Última decisão tomada:** **Fase 4 MVP — vínculo manual conversa↔tarefa (2026-06-17)**: `conversation_links` (≤1 primário, reversível, auditável) + counters em Task + UI (form em `/conversations/:id`, aba "Conversas" read-only em `/tasks/:id`). **Scorer/auto-link/sugestões adiados (v1).** Contrato em `F4_CONTRACT_DECISIONS.md`. *(commit/push pendentes de revisão.)*
- **Próxima decisão necessária:** próximo foco — **F4 v1** (scorer/sugestões/auto-link, quando houver tarefas reais) ou **Fase 5** (UI de conversa com turnos/markdown).

## Semáforo por área
| Área | Status | Observação |
|---|---|---|
| Arquitetura | 🟢 Verde | ADRs aceitos; baseline congelado |
| Rails Foundation | 🟢 Verde | App Rails 8.1.3 operacional; 15 testes verdes; CI local verde |
| Banco de dados | 🟢 Verde | Postgres 16 (omni_db) + migration de `users` aplicada; domínio na F2 |
| Migração Repo A | 🟢 Verde | **M2 concluído** — domínio CRUD completo (Client+Contact+Project+Task+Demand+ConvertDemand+TimeEntry); **migração de dados reais = N/A** (RepoA inativo, domínio vazio na origem) |
| Pipeline Repo B | 🟢 Verde | Externo, estável, intocado |
| Importação de conversas | 🟡 Amarelo | **F3.0→F3.3** (sync real de metadados: 1635 conversas; `source_nil=0`/`workspace_hash_nil=13`/`title_nil=1067`). **F3.3** resolveu folders (`orphan` 86→3; usuário redigido). **Turnos/UI/vínculo FORA** (ADR-018; F4/F5). M3 parcial (metadados+folders) |
| Vínculo conversa/tarefa | 🟡 Amarelo | **F4 MVP**: vínculo manual `conversation_links` (≤1 primário, reversível, auditável) + counters em Task. **scorer/auto-link/sugestões pendentes (v1)** |
| UI | 🟡 Amarelo | **F2.UI** (baseline visual provisório) + **F3.UI.1** (console read-only `/conversations`,`/sync_runs`) + **F4** (bloco "Vínculos" em `/conversations/:id`; aba "Conversas" read-only em `/tasks/:id`). **Não é a UI final** (turnos/markdown = Fase 5) |
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
