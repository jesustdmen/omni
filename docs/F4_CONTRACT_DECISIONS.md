# Omni/Continuity — Decisões de contrato da Fase 4 (vínculo conversa↔tarefa)

> Documento central das decisões da Fase 4. Complementa (não substitui)
> ROADMAP/FEATURE_MATRIX/PROJECT_STATUS/DELIVERY_LOG. Referências: ADR-013 (conversas
> pessoais fora de counters/scorer), ADR-014 (domínio compartilhado), ADR-016 (counters de Task).
> **Não há ADR específica da F4 nesta fatia** (MVP manual). Auto-link/scorer poderão exigir ADR (v1).

## 1. Status da Fase 4 (MVP — 2026-06-17)
- Implementada como **vínculo manual conversa↔tarefa**.
- **Sem scorer · sem `conversation_suggestions` · sem auto-link · sem F5** (turnos/markdown/conteúdo).

## 2. Decisões do MVP
- Criar a tabela **`conversation_links`**.
- **Vínculo manual** (pela UI), **reversível** por remoção do link (undo).
- `origin = 'manual'`; `created_by_id = current_user`.
- **Rotas aninhadas** em `conversations/:conversation_id/links` (apenas `create`/`destroy`).
- **Sem `time_entry_id`** nesta fatia.

## 3. Modelo (`conversation_links`)
| Campo | Tipo | Observação |
|---|---|---|
| `id` | uuid | PK |
| `conversation_id` | uuid | NOT NULL · FK→conversations (cascade) |
| `task_id` | uuid | NOT NULL · FK→tasks (cascade) |
| `link_type` | text | `'primary'`/`'mention'` · default `'primary'` |
| `origin` | text | `'manual'`/`'auto'`/`'suggestion'` · default `'manual'` |
| `confidence` | numeric(5,4) | nullable (uso futuro: auto-link) |
| `created_by_id` | **bigint** | nullable · FK→users (nullify) — segue `users.id` (Devise) |
| `created_at`/`updated_at` | timestamps | |

## 4. Regras de integridade
- **No máximo 1 `primary` por conversa** (índice único parcial `WHERE link_type='primary'`).
- `mention` **permitido junto** com `primary`.
- **Unique `(conversation_id, task_id, link_type)`** (sem duplicata exata).
- CHECKs: `link_type IN ('primary','mention')`; `origin IN ('manual','auto','suggestion')`; `confidence IS NULL OR 0..1`.
- **FK cascade** para conversation/task; **FK nullify** para user.

## 5. Counters em Task
- `conversation_count` e `last_conversation_at` **atualizados transacionalmente** no ciclo do link (`after_create`/`after_destroy`).
- **Só links `primary` contam**; `mention` **não conta**; conversas `personal` **não contam** (ADR-013).
- `last_conversation_at` = maior `last_ts` entre as conversas primárias não-personal.
- **Rake `tasks:recount_conversations`** recompõe os counters (auditoria; não cria links; não lê turnos/sessions/shards).

## 6. UI
- `/conversations/:id`: bloco **"Vínculos"** (lista) + **form manual** para vincular tarefa (select tarefa + tipo) + **remoção/undo**; guarda quando já existe primário.
- `/tasks/:id`: aba/seção **"Conversas"** (read-only) com as conversas vinculadas. **Sem turnos/conteúdo/markdown.**
- ERB auto-escapado; **sem `html_safe`**.

## 7. Fora de escopo (desta fatia)
`conversation_suggestions`; scorer; auto-link; leitura de `sessions.jsonl`; leitura de shards; importação de turnos; renderização de conteúdo de conversa; markdown/F5; alteração de importers; execução de sync.

## 8. Critérios de aceite (atendidos)
- Testes verdes; migration aplicada; **vínculo manual funciona**; **undo funciona**; **counters funcionam**; **índice único parcial impede 2 primários**; **não lê turnos/sessions/shards**; **não altera importers**; **não executa sync**.

## 9. Pendências futuras (F4 v1 / além)
- `conversation_suggestions` (status pending/accepted/rejected; aceite explícito vira link).
- **Scorer** (metadados: workspace/folder, título, proximidade temporal, files_changed; ≥0.85; sempre com `reason`; `personal` excluído).
- **Auto-link auditável/reversível** (LK-04) — **possível ADR** quando implementado.
- Possível **vínculo com `time_entries`** (`time_entry_id`) em fatia posterior.
