# Omni/Continuity — Roadmap de Migração

> **Baseline aprovado em 2026-06-16.** Fonte de verdade para fases, marcos e critérios de conclusão. Atualizar ao fim de cada fase e a cada mudança de escopo aprovada.

## Visão geral

- **Projeto:** Omni/Continuity.
- **Objetivo:** unificar TaskManager (TypeScript) + pipeline de conversas (Python) numa aplicação Rails, tratando conversas de IA como evidência viva do trabalho, vinculáveis a tarefas/projetos/clientes.
- **Motivação Rails:** domínio CRUD em camadas (mapeia 1:1 para Rails); mockup orientado a navegação + atalhos (sweet spot de Hotwire); uma stack; integridade/auth/testes consolidados.
- **Unificado:** domínio de trabalho (Repo A) + conversas normalizadas (saída do Repo B) + decisões de produto do mockup (vínculo, triagem, diário, sync).
- **Não reescrito no MVP:** o pipeline Python permanece externo e intocado; o Rails consome `output/normalized/` e não reparseia bruto.
- **Princípios de arquitetura:**
  1. Integridade e testabilidade acima de UI.
  2. Idempotência por `thread_id` em todo import.
  3. Toda operação multi-entidade é transacional.
  4. Auto-link nunca silencioso (auditável e reversível).
  5. Conteúdo de conversa é não confiável (sanitização server-side).
  6. Não portar o parser sem testes de caracterização.
  7. Diretórios de referência (`_origem/`, `_mockup/`) não são fonte de código; a implementação do produto ocorre em `app/` (ver [CONSTRAINTS.md](CONSTRAINTS.md)).

## Fases do projeto

### Fase 0 — Decisão arquitetural — ✅ Concluída (baseline aprovado, 2026-06-16)
- **Objetivo:** transformar o diagnóstico em decisões revisáveis.
- **Entregáveis:** ADRs 001–017 (Aceito); escopo MVP/v1/Roadmap; modelo de dados + DDL de revisão; estratégia de import; corpus (planejado); matriz de riscos; 6 documentos de controle.
- **Critérios de aceite:** ✅ ADRs aceitos; ✅ 9 decisões abertas confirmadas; ✅ modelo/DDL revisados.
- **Marco:** M0 — concluído.

### Fase 1 — Rails Foundation — ✅ Concluída (M1, 2026-06-16)
- **Objetivo:** base operacional (Rails 8, Postgres, auth, authz, jobs, segurança, CI).
- **Entregáveis:** Devise (migração bcrypt custo ~10 + re-hash oportunístico); Pundit; Solid Queue + smoke job; rack-attack; CSRF nativo; layout/sidebar (ViewComponent); credentials; CI.
- **Critérios de aceite:** login de usuário migrado sem reset; testes auth/authz/CSRF/rate-limit verdes; job fora do request.
- **Dependências:** M0 (✅). **Bloqueador restante:** autorização explícita do usuário.
- **NÃO fazer:** conversas; domínio além de `users`; importar dados.
- **Marco:** M1.

### Fase 2 — Migração do domínio de trabalho — ✅ Concluída (M2, 2026-06-17)
- **Entregáveis:** clients (+`workspace_paths`, cnpj nullable + partial unique)/contacts/projects/tasks (+`conversation_count`/`last_conversation_at`)/demands/time_entries (+`conversation_id` null); ConvertDemand transacional; `/tasks/:id` página (abas Detalhes/Time/Histórico/Demanda); migração de dados; auditoria.
- **Status:** **WD-01..WD-07 entregues (2026-06-17) — domínio/CRUD completo**. **Migração de dados reais = N/A**: o RepoA estava **inativo**; o snapshot real (`postgres-volume-snapshot-20260328.tgz`, DB `app_v2`) tem o **domínio vazio** (clients/contacts/projects/tasks/demands/time_entries = 0; só 2 usuários de teste, **não migrados**). Sem massa histórica a importar.
- **Critérios de aceite:** convert atômico; paridade CRUD. (Contagens origem×destino: **N/A** — origem vazia.)
- **NÃO fazer:** sync/conversas/scorer; campos de Task de v1.
- **Marco:** M2.

### Fase 3 — Sync de conversas normalizadas — 🟡 Em progresso (sync de metadados real entregue; módulo completo de conversas não)
- **F3.0 (2026-06-17) — preparação/contrato/corpus** (ADR-018, `F3_CONTRACT_DECISIONS.md`, corpus sintético).
- **F3.1 (2026-06-17, `fe291d9`) — CONCLUÍDA:** tabelas `conversations`/`workspace_maps`/`sync_runs`/`sync_run_items` + serviço `Sync::ImportSummaries` + rake `sync:summaries`, **idempotente por `thread_id`**, **só summaries/metadados** (turnos/`sessions.jsonl`/shards fora — ADR-018).
- **F3.2 (2026-06-17) — CONCLUÍDA:** **primeiro sync real controlado** de `summaries.jsonl` (`output/normalized/`, allowlist `:ro` + `pg_dump`), em `development`: **1635 conversas**, `status=partial` (1 linha sem `thread_id`), idempotente (re-sync `imported=0/updated=1635`). Domínio preservado.
- **F3.2.1 (2026-06-17, `bd0a9ce`) — CONCLUÍDA:** correção do merge de escalares com `last_ts` nulo (regra de empate/ordem-de-leitura + backfill): `source_nil` 1069→0, `workspace_hash_nil`=13, `title_nil`=1067 (limitação do dado).
- **F3.3 (2026-06-17) — CONCLUÍDA:** `Sync::ResolveWorkspaceFolders` resolveu `workspace_maps.folder` a partir de `raw/.../workspaceStorage/<hash>/workspace.json` (**exceção controlada ao ADR-008**, read-only; usuário redigido `<USER>`): **órfãos 86 → 3**; `WorkspaceMap=86` (sem novos); domínio/sync inalterados.
- **Ainda FORA da Fase 3:** turnos (`sessions.jsonl`/shards lazy — antes da F5), render de mensagens, vínculo conversa↔tarefa (F4), UI/triagem (F5/F6).
- **Entregáveis:** `conversations` (metadados), `workspace_maps`, `sync_runs`/`sync_run_items`; turnos lazy; streaming + upsert por `thread_id`; resiliência a linha malformada.
- **Critérios de aceite:** re-sync não duplica; 240 MB sem OOM; linha inválida → `partial`.
- **Dependências BLOQUEANTES da Fase 3:**
  1. Corpus de caracterização do parser definido e criado.
  2. Validação técnica `thread_id → shards/messages/<sha1>` confirmada.
  3. Decisão `schema_version` no JSONL aplicada.
- **NÃO fazer:** import de turnos em massa; tocar no pipeline; scorer.
- **Marco:** M3.

### Fase 4 — Vínculo conversa ↔ tarefa — ⬜ Não iniciada
- **Entregáveis:** `conversation_links` (partial-unique primário), `conversation_suggestions`, scorer, auto-link ≥0.85 auditado/reversível, counter cache.
- **Critérios de aceite:** ≤1 primário por conversa (constraint); auto-link logado/reversível.
- **Marco:** M4.

### Fase 5 — UI unificada — ⬜ Não iniciada
- **Entregáveis:** aba Conversas; lista+detalhe de conversa (markdown sanitizado); modal vincular (Ctrl+L); criar tarefa de conversa; dashboard; empty/error states.
- **Critérios de aceite:** fluxos MVP; payload XSS neutralizado.
- **Marco:** M5.

### Fase 6 — Diário, triagem e automações — ⬜ Não iniciada
- **Entregáveis:** inbox de triagem (lote/atalhos); diário (view sob demanda); settings de sync (agenda/retenção/histórico); handoff externo; workspaces órfãos.
- **Critérios de aceite:** aceitar lote atômico; retenção roda; handoff abre externo.
- **Marco:** M6.

### Fase 7 — Hardening, testes e documentação — ⬜ Não iniciada
- **Entregáveis:** suíte completa; performance de import; backup/rollback; runbook; rake task de homologação.
- **Critérios de aceite:** suíte verde; import dentro do SLA; runbook validado.
- **Marco:** M7.

## Marcos

| Marco | Descrição | Fase | Status |
|---|---|---|---|
| M0 | Decisões arquiteturais aprovadas | 0 | ✅ Concluído (2026-06-16) |
| M1 | Rails base operacional | 1 | ✅ Concluído (2026-06-16) |
| M2 | Domínio de trabalho migrado | 2 | ✅ Concluído (2026-06-17) — WD-01..07 CRUD completo; **migração de dados reais N/A** (RepoA inativo / domínio vazio na origem) |
| M3 | Importação de conversas idempotente | 3 | 🟡 Em progresso (sync real de **metadados** entregue: 1635 conversas, idempotente, `bd0a9ce`; **módulo completo** de conversas — turnos/UI/vínculo — ainda fora) |
| M4 | Vínculo conversa/tarefa operacional | 4 | ⬜ Não iniciado |
| M5 | UI principal unificada | 5 | ⬜ Não iniciado |
| M6 | Triagem, diário e sync operacional | 6 | ⬜ Não iniciado |
| M7 | Projeto estabilizado e documentado | 7 | ⬜ Não iniciado |
