# Omni — Roadmap de Migração

> **Baseline aprovado em 2026-06-16.** Fonte de verdade para fases, marcos e critérios de conclusão. Atualizar ao fim de cada fase e a cada mudança de escopo aprovada.

## Visão geral

- **Projeto:** Omni.
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

### Fase 3 — Sync de conversas normalizadas — 🟢 MVP de metadados CONCLUÍDO (módulo completo de conversas → roadmap)
- **F3.0 (2026-06-17) — preparação/contrato/corpus** (ADR-018, `F3_CONTRACT_DECISIONS.md`, corpus sintético).
- **F3.1 (2026-06-17, `fe291d9`) — CONCLUÍDA:** tabelas `conversations`/`workspace_maps`/`sync_runs`/`sync_run_items` + serviço `Sync::ImportSummaries` + rake `sync:summaries`, **idempotente por `thread_id`**, **só summaries/metadados** (turnos/`sessions.jsonl`/shards fora — ADR-018).
- **F3.2 (2026-06-17) — CONCLUÍDA:** **primeiro sync real controlado** de `summaries.jsonl` (`output/normalized/`, allowlist `:ro` + `pg_dump`), em `development`: **1635 conversas**, `status=partial` (1 linha sem `thread_id`), idempotente (re-sync `imported=0/updated=1635`). Domínio preservado.
- **F3.2.1 (2026-06-17, `bd0a9ce`) — CONCLUÍDA:** correção do merge de escalares com `last_ts` nulo (regra de empate/ordem-de-leitura + backfill): `source_nil` 1069→0, `workspace_hash_nil`=13, `title_nil`=1067 (limitação do dado).
- **F3.3 (2026-06-17) — CONCLUÍDA:** `Sync::ResolveWorkspaceFolders` resolveu `workspace_maps.folder` a partir de `raw/.../workspaceStorage/<hash>/workspace.json` (**exceção controlada ao ADR-008**, read-only; usuário redigido `<USER>`): **órfãos 86 → 3**; `WorkspaceMap=86` (sem novos); domínio/sync inalterados.
- **F3.UI.1 (2026-06-17) — CONCLUÍDA:** **console read-only de validação** (`/conversations`, `/sync_runs` — só metadados, paginado). **Não é a UI da Fase 5**: sem render de turnos/markdown, sem leitura de `sessions.jsonl`/shards, sem vínculo conversa↔tarefa, sem sync, sem alteração de dados.
- **MVP de metadados FECHADO (readiness pós-F5.1.4):** sync real idempotente (1635 conversas), folders/workspaces resolvidos, `sync_runs`/`turn_sources` íntegros, índice de turnos + loader lazy entregues; DB dev higienizado (1635/1/129482/5/1, órfãs 0).
- **Pendências → roadmap:** OP-01 (sync manual pela UI), OP-03 (histórico/observabilidade de sync mais rica), CV-03 (títulos de sessão dedicados), CV-10 (tags). Import em massa de turnos permanece N/A (lazy via ADR-021).
- **Ainda FORA da Fase 3:** turnos (`sessions.jsonl`/shards lazy — antes da F5), render de mensagens, vínculo conversa↔tarefa (F4), UI rica/triagem (F5/F6).
- **Entregáveis:** `conversations` (metadados), `workspace_maps`, `sync_runs`/`sync_run_items`; turnos lazy; streaming + upsert por `thread_id`; resiliência a linha malformada.
- **Critérios de aceite:** re-sync não duplica; 240 MB sem OOM; linha inválida → `partial`.
- **Dependências originalmente bloqueantes — resolvidas na F3.0→F3.3:**
  1. Corpus de caracterização do parser definido e criado.
  2. Validação técnica `thread_id → shards/messages/<sha1>` confirmada.
  3. Decisão `schema_version` no JSONL aplicada.
- **NÃO fazer:** import de turnos em massa; tocar no pipeline; scorer.
- **Marco:** M3.

### Fase 4 — Vínculo conversa ↔ tarefa — 🟢 MVP manual CONCLUÍDO (scorer/auto-link → v1/roadmap)
- **Entregáveis:** `conversation_links` (partial-unique primário), `conversation_suggestions`, scorer, auto-link ≥0.85 auditado/reversível, counter cache.
- **F4 MVP (2026-06-17) — CONCLUÍDO:** `conversation_links` (uuid; FK conversa/tarefa cascade; `link_type` primary/mention; `origin`; `confidence`; `created_by` bigint; **partial-unique ≤1 primário**; unique triplo); **vínculo manual** (form em `/conversations/:id`, aninhado `conversations/:id/links` create/destroy), **reversível** (undo) e **auditável** (origin/created_by); **counters em Task** (`conversation_count`/`last_conversation_at`) mantidos **transacionalmente** (só `primary`, ignora `personal`) + rake `tasks:recount_conversations`; aba "Conversas" da task lista vinculadas (read-only). **LK-01/02/03/07/08.** Detalhes em [`F4_CONTRACT_DECISIONS.md`](F4_CONTRACT_DECISIONS.md).
- **MVP manual FECHADO (readiness pós-F5.1.4):** vínculo conversa↔tarefa entregue — `primary`/`mention`, reversível (undo), auditável (origin/created_by), counters transacionais; partial-unique + CHECKs; validação dupla (DB + modelo). LK-01/02/03/07/08.
- **Pendências → v1/roadmap:** `conversation_suggestions` + **scorer** (LK-05), **auto-link ≥0.85** auditável/reversível (LK-04, possível ADR), **aceite em lote** (LK-06), `time_entry_id` no link; aba Conversas com render (depende de F5).
- **Critérios de aceite:** ≤1 primário por conversa (constraint) ✔; auto-link logado/reversível (pendente — v1).
- **Marco:** M4 — MVP manual concluído; v1/scorer em roadmap.

### Fase 5 — UI unificada — 🟡 Em progresso (F5.1 entregue)
- **Decisão pré-F5 (2026-06-17):** lazy-load de turnos definido no **[ADR-021](adr/ADR-021-lazy-load-turnos-via-indice-offsets.md)** (índice de offsets por `thread_id` em `sessions.jsonl`; ponteiros, não conteúdo; `seek`+`readline`; sem importar turnos para o banco). Fronteira inicial em [`F5_CONTRACT_DECISIONS.md`](F5_CONTRACT_DECISIONS.md).
- **Fatia pré-F5 ENTREGUE (2026-06-17):** `turn_sources` + `conversation_turn_refs` (só ponteiros), `Sync::BuildConversationTurnRefs` (streaming + fingerprint + idempotente), `ConversationTurns::LazyLoader` (`seek` + valida `thread_id` + sem full-scan), rake `sync:turn_refs`. Build real: 129.482 refs, **covered 1635/1635**. **Falta:** a UI de conversa (render sanitizado).
- **F5.1 (2026-06-18) — CONCLUÍDA:** render **read-only** de turnos em `/conversations/:id` (dentro do `show`; `Conversations::TurnListComponent`), consumindo o `LazyLoader`; `TURNS_PER_PAGE=50`; `role`/`timestamp`/texto **auto-escapado** + `tool_input` em `<pre>`; estados `:ok/:empty/:stale/:not_found`/`mismatched`; **`personal`=b1** (conteúdo oculto, sem dono); **sem markdown/auto-link/`html_safe`** (grep-guard); **CSP restrita**. 221 testes verdes; validado em conversa real (177 turnos). **CV-05/CV-06/CV-08 parciais.**
- **F5.1.1 (2026-06-18, `a01efbd`) — CONCLUÍDA:** correção do artefato ERB `). %>` (comentário do componente continha `<%= %>`) + **cor de badge por role** via allowlist (`ROLE_TONES`); render read-only mantido; turnos `user` ficam visíveis.
- **F5.1.2 (2026-06-18) — CONCLUÍDA:** consolidação documental (registro F5.1.1; remoção de nota obsoleta; addendum ADR-013 `personal` boolean+b1; padronização "Omni") + **persistência do mount `/normalized:ro`** no fluxo de subida (`.devstack/up.sh`). Sem mudança de comportamento de app.
- **F5.1.3 (2026-06-18, `8d32f4f`) — CONCLUÍDA:** oculta `source_file` cru em `/sync_runs/:id` via helper `safe_basename` (só o nome do arquivo; sem `/normalized`//`/tmp`//`/home`//`C:\Users`//`file://`). +4 testes.
- **F5.1.4 (2026-06-18) — CONCLUÍDA (DB-only):** limpeza transacional dos resíduos sintéticos de auditoria no DB dev (9 refs + 3 turn_sources `/tmp` + 3 conversas `tXSS*` + 3 sync_runs `/tmp`; backup gitignored). DB dev fiel ao real (1635/1/129482/5/1, órfãs 0). Registrada em `8f65cf8`.
- **F5.1.5 (2026-06-18, `821f495`) — CONCLUÍDA:** redação conservadora/idempotente de PII/segredos em `text`/`tool_input` no render (`ConversationTurns::PiiRedactor`) → `<EMAIL>`/`<SECRET>`/`<USER>`. Suíte 235/861/0.
- **F5.2 (2026-06-18) — CONCLUÍDA:** markdown (GFM) sanitizado no `text` (CV-07) via `ConversationTurns::MarkdownRenderer` (`commonmarker 2.8.2` modo seguro + `Rails::HTML5::SafeListSanitizer` allowlist + hardening de links); `tool_input` segue em `<pre>`; `html_safe` só no renderer (grep-guard mantido). Suíte 257/966/0; brakeman 0; bundler-audit 0.
- **F5.1 = sub-entrega CONCLUÍDA; a Fase 5 permanece ABERTA** (o grosso da UI unificada é F5.2+).
- **F5.3 (2026-06-18) — CONCLUÍDA (UI-10):** criar tarefa a partir da conversa — `ConversationTasksController` (rota aninhada `conversations/:id/tasks`) cria `Task` + `ConversationLink` `primary`/`manual` em transação (rollback sem órfã; counters via `after_create`); ação oculta quando já há `primary`. Suíte 264/1016/0.
- **F5.4 (2026-06-19) — CONCLUÍDA (CV-04):** lista de conversas acionável — coluna **Vínculo** (sem vínculo + "Criar tarefa" / primária linkando à task / menção) + filtro `link` (`none`/`primary`/`mention`); eager loading sem N+1; turnos não carregados. Triagem leve (não é o inbox UI-05). Suíte 272/1047/0.
- **Ainda FORA (F5.5+):** **inbox de triagem com lote/atalhos (UI-05, v1)**, syntax highlight, busca, virtualização, modal vincular (Ctrl+L, UI-09), dashboard (UI-01), abas reais da task, tags, arquivos alterados. *(Lista acionável CV-04 entregue na F5.4; criar tarefa UI-10 na F5.3; markdown na F5.2; PII na F5.1.5.)*
- **Entregáveis:** índice de turnos (ADR-021 ✓); aba Conversas; lista+detalhe de conversa (markdown sanitizado — ADR-012); modal vincular (Ctrl+L); criar tarefa de conversa; dashboard; empty/error states.
- **Critérios de aceite:** abertura lazy sem full-scan; turnos ordenados; fluxos MVP; payload XSS neutralizado; `tool_input` nunca HTML; `personal` respeitado.
- **Marco:** M5.

### Fase 6 — Diário, triagem e automações — ⬜ Não iniciada
- **Entregáveis:** inbox de triagem (lote/atalhos); diário (view sob demanda); settings de sync (agenda/retenção/histórico); handoff externo; workspaces órfãos.
- **Critérios de aceite:** aceitar lote atômico; retenção roda; handoff abre externo.
- **Marco:** M6.

### Fase 7 — Hardening, testes e documentação (produção) — ⬜ Não iniciada
- **Entregáveis:** suíte completa; performance de import; backup/rollback; runbook; rake task de homologação.
- **Critérios de aceite:** suíte verde; import dentro do SLA; runbook validado.
- **Readiness de produção (diagnóstico pós-F5.1.4 — produção NUNCA exercida):** bloqueadores conhecidos a tratar na F7 —
  `production.rb` não endurecido (`force_ssl`/`assume_ssl`/`config.hosts` comentados); schemas **Solid cache/queue/cable** ausentes (só `db/queue_schema.rb`); `cable.yml` de prod ainda em **Redis** (não `solid_cable`); **Kamal/deploy ausente** (`config/deploy.yml`/`.kamal/`); **admin seed** ausente (`db/seeds.rb` vazio); **worker de jobs** (Solid Queue) não definido; **`/normalized` em produção indefinido** (sem origem/volume → `:stale`); **pipeline Python** sem topologia de prod; **backup/restore/rollback** de prod pendentes; `action_mailer` host placeholder. *(Redação de PII em `text`/`tool_input` no render entregue na F5.1.5; ampliação p/ CPF/telefone/IP/segredos não-rotulados segue como follow-up.)*
- **Não bloqueante (corrigir na F7):** entrada órfã `001 NO FILE` em `schema_migrations`; `timezone`/`locale` nos defaults (UTC/:en) apesar da UI pt-BR.
- **Pré-requisito de exposição externa/multi-tenant:** F7 completa + **isolamento por owner/tenant** (hoje ADR-014 domínio compartilhado) + redação de PII.
- **Marco:** M7.

## Marcos

| Marco | Descrição | Fase | Status |
|---|---|---|---|
| M0 | Decisões arquiteturais aprovadas | 0 | ✅ Concluído (2026-06-16) |
| M1 | Rails base operacional | 1 | ✅ Concluído (2026-06-16) |
| M2 | Domínio de trabalho migrado | 2 | ✅ Concluído (2026-06-17) — WD-01..07 CRUD completo; **migração de dados reais N/A** (RepoA inativo / domínio vazio na origem) |
| M3 | Importação de conversas idempotente | 3 | 🟢 MVP de metadados concluído (1635 conversas idempotentes + folders + índice de turnos/loader lazy); **módulo completo** (OP-01/03, CV-03/10) → roadmap |
| M4 | Vínculo conversa/tarefa operacional | 4 | 🟢 MVP manual concluído (`conversation_links` reversível/auditável + counters; LK-01/02/03/07/08); scorer/sugestões/auto-link/aceite-lote/`time_entry_id` → v1 |
| M5 | UI principal unificada | 5 | 🟡 Em progresso (F5.1→F5.1.4 entregues: turnos read-only em `/conversations/:id`); F5.2 markdown/UI-01/04/09/10/busca/triagem + PII pendentes |
| M6 | Triagem, diário e sync operacional | 6 | ⬜ Não iniciado |
| M7 | Projeto estabilizado e documentado | 7 | ⬜ Não iniciado |
