# Omni/Continuity — Status Consolidado do Projeto

> Snapshot: **2026-06-17**. Atualizar ao fim de cada sessão de trabalho e em toda decisão/entrega.

## Status geral
- **Fase atual:** Fase 2 — **domínio CRUD COMPLETO (2026-06-17)**: F2.1–F2.4 (Client+Contact, Project, Task base + `/tasks/:id`, Demand + ConvertDemand) + **F2.5 TimeEntry (WD-07) concluída**. M1 fechado. **F2.UI — baseline visual hi-fi provisório aprovado (2026-06-17)** (apresentação apenas; não é a UI final, que cabe à Fase 5; sem features novas). **M2 pleno (contagens origem×destino) ainda pendente de migração/validação de dados reais — não declarar M2 100% fechado.**
- **Próxima fase:** Fase 3 — sync de conversas normalizadas. **F3.0 concluída (2026-06-17): preparação/contrato** (ADR-018, decisões de contrato, corpus sintético) — **sem código**. **F3.1 (migrations + importer de `summaries.jsonl`) aguarda autorização.** Alternativa paralela: migração de dados reais (autorização + backup) para fechar o **M2 pleno**.
- **Status geral:** Domínio CRUD completo (F2). **F3.0 = preparação de contrato concluída**; F3 (implementação) ainda não iniciada. M2 pleno pendente de dados reais. 137 testes verdes; lint/brakeman/bundler-audit verdes. Sem importação de dados reais.
- **Stack provisionada:** Rails 8.1.3 + PostgreSQL 16 via Docker (sem instalar nada no host; `_origem/` intocado).
- **Bloqueadores da Fase 2:** Nenhum, exceto autorização explícita do usuário.
- **Bloqueadores futuros (Fase 3):** **endereçados na F3.0** — corpus sintético criado (`test/fixtures/normalized_corpus/`); `thread_id → shard` resolvido via **ADR-018** (mapeamento refutado; turnos fora da F3); `schema_version` decidido (por-run no Rails, ver `F3_CONTRACT_DECISIONS.md`). Resta a **autorização** para a F3.1 (código).
- **Ação de segurança:** dump do RepoA fora do versionamento — protegido no repo de planejamento via `.gitignore`; RepoA tratado como referência/leitura.
- **Última decisão tomada:** **F3.0 — contrato/decisões/corpus (2026-06-17)**: ADR-018 (addendum ao ADR-009), `F3_CONTRACT_DECISIONS.md` e corpus sintético; repo único publicado em `origin/main` (ADR-019).
- **Próxima decisão necessária:** autorizar a **F3.1** (migrations + importer idempotente de `summaries.jsonl`) **ou** a migração/validação de dados reais para fechar o M2 pleno.

## Semáforo por área
| Área | Status | Observação |
|---|---|---|
| Arquitetura | 🟢 Verde | ADRs aceitos; baseline congelado |
| Rails Foundation | 🟢 Verde | App Rails 8.1.3 operacional; 15 testes verdes; CI local verde |
| Banco de dados | 🟢 Verde | Postgres 16 (omni_db) + migration de `users` aplicada; domínio na F2 |
| Migração Repo A | 🟡 Amarelo | Domínio CRUD completo (Client+Contact+Project+Task+Demand+ConvertDemand+**TimeEntry**); **migração/validação de dados reais pendente** (M2 pleno) |
| Pipeline Repo B | 🟢 Verde | Externo, estável, intocado |
| Importação de conversas | 🟡 Amarelo | **F3.0 (contrato/decisões/corpus) concluída**; F3.1 (migrations + importer de `summaries.jsonl`) aguarda autorização. Turnos fora da F3 (ADR-018) |
| Vínculo conversa/tarefa | ⬜ Cinza | Modelado; não iniciado |
| UI | 🟡 Amarelo | **F2.UI**: baseline visual hi-fi provisório nas telas existentes (shell/sidebar/topbar, dashboard, listas, detalhes, forms). Não é a UI final — UI unificada real fica na Fase 5 |
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
- [ ] Domínio migrado. *(CRUD completo em 2026-06-17; migração/validação de dados reais pendente — M2 pleno em aberto.)*
- [ ] Conversas importadas.
- [ ] Vínculos implementados.
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
