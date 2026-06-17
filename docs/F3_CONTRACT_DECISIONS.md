# Omni/Continuity — Decisões de contrato da Fase 3 (F3.0)

> **F3.0 = preparação/contrato. Não é implementação.** Nenhuma migration/model/importer foi
> criada; nenhum dado real foi importado. A F3.1 (código) aguarda autorização explícita.
> Referências: [ADR-018](adr/ADR-018-addendum-adr-009-shards-turnos-lazy.md),
> [ADR-009](adr/ADR-009-lazy-conversation-turns.md), [ADR-008](adr/ADR-008-output-normalized-contract.md),
> [ADR-013](adr/ADR-013-personal-conversations.md), [ADR-014](adr/ADR-014-multiuser-policy.md).

## Contexto observado (RepoB, somente leitura)
`_origem/_repob/pipeline/output/normalized/` contém: `summaries.jsonl` (~1.1 MB · 2399 linhas ·
1635 `thread_id` distintos), `sessions.jsonl` (~240 MB · 129.500 linhas), `session_titles.json`,
`tags.json`, e `shards/{messages,summaries}/<sha1>.jsonl` (2034 cada). As linhas JSONL **não**
carregam `schema_version`. O `thread_id` aparece em formato **UUID** e também **sha1/40-hex**.

---

## 1. `schema_version`
- **Não alterar o RepoB** (referência; ADR-007/008).
- O Rails grava `schema_version` **por execução** em `sync_runs.schema_version`, a partir de uma
  **constante de contrato** no Rails (ex.: `Sync::CONTRACT_VERSION`), alinhada ao
  `_SHARD_SCHEMA_VERSION` observado no pipeline (hoje `"4"`).
- **Parser defensivo:** campo ausente / formato inesperado vira `skipped` / `error_lines` e a run
  conclui como `partial` — **nunca crash global**.
- Emissão de `schema_version` por linha no RepoB = **melhoria futura** (registrada, não nesta fase).

## 2. `thread_id`
- Coluna `conversations.thread_id` é **`text`/string** (NÃO `uuid`) — há valores UUID e sha1/40-hex.
- **Unique index** em `thread_id` (chave de idempotência).
- Nunca assumir formato/validação de UUID.

## 3. Regra determinística de merge por `thread_id`
Aplicada no upsert (idempotente; `summaries.jsonl` tem múltiplas linhas por `thread_id`):
- **Idempotência por `thread_id`** (unique + upsert).
- `first_ts` = **menor** valor **não-nulo**.
- `last_ts` = **maior** valor **não-nulo**.
- `message_count`, `user_turns`, `assistant_turns`, `tool_calls` = **maior valor observado** (não soma cega).
- `files_changed` = **união distinta**.
- `workspace_hash` = o da linha de **maior `last_ts`** (nulo tratado como mínimo; empate → ordem de leitura).
- `source` = o da linha de **maior `last_ts`** (mesmo desempate).
- `title` = `session_titles.json[thread_id]` quando existir; senão título da linha de **maior `last_ts`**;
  senão `nil`/"New Chat".
- **Métricas:** registrar `lines_processed`, `imported`, `updated`, `skipped`, `error_lines`
  **separados** de `Conversation.count` (linhas ≠ conversas; ex.: 2399 linhas → ~1635 conversas).

> **Correção F3.2.1 (2026-06-17, `bd0a9ce`):** o primeiro sync real expôs que a implementação
> original só atribuía escalares (`source`/`workspace_hash`/`title`) na linha **estritamente mais
> nova** — então threads com **todas** as linhas de `last_ts` nulo (no dado real: `chat_editing_state`,
> `agent_sessions`) ficavam com escalares nulos, divergindo da regra acima (**empate → ordem de
> leitura**; todos nulos → primeira linha vence). O `fold` foi corrigido para: (a) primeira linha
> observada vencer quando ainda não há vencedor; (b) **backfill** (`fill-if-empty`) de escalares
> ainda nulos em registros existentes; (c) não sobrescrever valor presente por nil. A regra desta
> seção não mudou — só a implementação passou a respeitá-la.

## Resultado do primeiro sync real (F3.2 / F3.2.1 — `development`)
- Fonte: `summaries.jsonl` (2399 linhas) + `session_titles.json`; **`sessions.jsonl`/shards/tags fora** (ADR-018); origem montada **`:ro`**; backup `app/tmp/dev_sync_backup_pre_f32_20260617_151436.sql`.
- 1ª execução: `lines_processed=2399, imported=1635, updated=0, skipped=1, error_lines=0, status=partial` (1 linha sem `thread_id`). Re-sync: `imported=0, updated=1635` (idempotente).
- Pós-F3.2.1: **`Conversation.count=1635`**, `source_nil=0`, `workspace_hash_nil=13`, `title_nil=1067` (limitação do dado — não bug), `WorkspaceMap=86` (**todos órfãos**; resolução de `folder` → F3.3). Domínio inalterado.

## 4. Turnos fora da F3 (ver ADR-018)
- A regra `thread_id → shards/messages/<sha1>` foi **refutada**; shard = `sha1("v4:<file_type>:<source_path>")`.
- **F3 não importa turnos.** `sessions.jsonl` e `shards/messages/` ficam fora.
- Lazy-load de turnos será **decidido antes da F5** (provável: índice `thread_id → offset/shard`),
  **sem implementação agora**.

## 5. `user_id` / `personal` (ADR-013/014)
- O contrato normalizado **não traz `user_id`** (histórico local, monousuário de fato); domínio
  compartilhado no MVP (ADR-014).
- **Decisão (preparação futura, sem enforcement agora):** `conversations.user_id` **nullable**
  (FK→`users`, `ON DELETE SET NULL`) e `personal` **boolean default false**,
  **sem lógica/escopo Pundit nesta fase**. O comportamento de conversas pessoais (ADR-013) entra na **F5**.
- Consistente com o padrão já usado (`time_entries.conversation_id`, counters de `tasks`): coluna
  presente, sem comportamento.
- **Tipo de `user_id` = `bigint` (não `uuid`).** Confirmado no schema (F3.1): a tabela local `users`
  usa **PK `bigint`** (gerador do Devise; `create_table "users"` sem `id: :uuid`). Como `user_id` é
  **FK para `users.id`**, ele **deve seguir o tipo real da PK** — um FK `uuid → bigint` é inválido
  (`PG::DatatypeMismatch`). A leitura de prontidão sugeria `uuid`; **corrigido para `bigint`** na
  implementação. (Observação: as tabelas de domínio do produto usam `uuid`, mas `users` permaneceu
  `bigint` desde a Fundação/M1.)
- **`user_id` NÃO representa ID externo** do RepoA/RepoB. Se um dia for preciso preservar identidade
  de usuário de origem, isso deve ser **outra coluna** dedicada (ex.: `source_user_id text` /
  `external_user_id text`), **não** este FK local.

---

## Escopo da F3.1 (quando autorizada — não iniciar agora)
Migrations + importer idempotente focados **somente** em: `conversations`, `workspace_maps`,
`sync_runs`, `sync_run_items`; importer **streaming** de `summaries.jsonl` com merge por `thread_id`
(§3), join com `session_titles.json`, contadores e status `ok/partial/error`; testes com o
**corpus sintético** em `test/fixtures/normalized_corpus/`. **Sem turnos, sem UI final, sem F4/F5,
sem dados reais.**
