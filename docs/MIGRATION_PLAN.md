# Omni/Continuity — Plano de Migração

> **Baseline aprovado em 2026-06-16.** Reflete ADRs 001–017 (Aceito). Complementa o ROADMAP.

## Escopo da migração

- **Repo A (TaskManager):** domínio (clients/contacts/projects/tasks/demands/time_entries/users), auth sessão+bcrypt, CSRF, rate-limit, paginação/filtros, componentes de UI, dados reais (snapshot).
- **Repo B (Pipeline):** apenas a saída normalizada (`summaries.jsonl`, `sessions.jsonl`, `session_titles.json`) + resolução `workspace_hash → pasta`. O código Python NÃO migra.
- **Mockup:** vínculo, scorer/auto-link, triagem, diário, settings de sync, `/tasks/:id` página, `Client.workspace_paths`, handoff.
- **Descartado:** `csurf` (CSRF nativo Rails); camada `repositories` separada; multi-ambiente via AsyncLocalStorage/Proxy (ADR-015); endpoint de clone via `spawn`.
- **Fora do Rails (temporário):** pipeline Python (ingest/normalize/report) e viewer Streamlit.

## Estratégia de migração

1. **Arquitetura:** Express/Drizzle em camadas → Rails monólito Hotwire + ViewComponent; jobs em Solid Queue. (ADR-001, 005)
2. **Banco de dados:** Postgres → Postgres; preservar UUIDs; CNPJ nullable + partial unique (ADR-017); counters em tasks (ADR-016); entidades de conversa novas. (ADR-006)
3. **Funcional:** paridade (F2) → conversas/vínculos (F3–F4) → fluxos do mockup (F5–F6).
4. **UI:** React/Vite → Hotwire; detalhe de tarefa vira página `/tasks/:id`. (ADR-001, 002)
5. **Pipeline de conversas:** externo; Rails consome `output/normalized/`; turnos lazy (ADR-009); agendador externo dispara o pipeline, Rails só lê (ADR-011). (ADR-007, 008)
6. **Documentação:** diagnóstico + ADRs + 6 documentos de controle; runbook na F7.
7. **Testes:** corpus de caracterização antes da F3; model/request/system/job/policy ao longo; performance na F7.

## Matriz origem → destino

| Origem | Destino Rails | Estratégia | Risco | Validação | Fase |
|---|---|---|---|---|---|
| `users` | `users` (Devise) | `password_hash`→`encrypted_password`; manter custo bcrypt (~10); re-hash oportunístico no login; não bloquear migrados | M | login de amostra sem reset | 2 |
| `clients` | `clients` (+`workspace_paths`) | `cnpj` nullable; `cnpj=''`→NULL; partial unique WHERE cnpj IS NOT NULL | B | count + partial-unique | 2 |
| `contacts` | `contacts` | direto | B | count + FK | 2 |
| `projects` | `projects` | direto | B | count + FK | 2 |
| `tasks` | `tasks` (+counters) | direto; status enum 1:1; `conversation_count`/`last_conversation_at` | B | count + distribuição status | 2 |
| `demands` | `demands` | status text→(enum?); `converted_at`; convert atômico | M | count + convertidas atômicas | 2 |
| `time_entries` | `time_entries` (+`conversation_id` null) | direto | B | count + soma `duration` | 2 |
| `summaries.jsonl` | `conversations` | streaming + upsert por `thread_id` | A | linhas válidas == count | 3 |
| `session_titles.json` | `conversations.title` | join por `thread_id` | B | títulos esperados | 3 |
| `sessions.jsonl` | `conversation_turns` | LAZY/sob demanda por shard — não importar no sync inicial | A | turnos == `turn_count` | 3/5 |
| ingest `workspace.json` | `workspace_maps` | upsert `hash→folder` | B | hashes resolvidos; órfãos listáveis | 3 |
| (scorer) | `conversation_links` | regras + auto-link ≥0.85 | M | partial-unique + auditoria | 4 |
| (settings de sync) | `sync_runs`/`sync_run_items` | registro por execução | M | parcial/erro registrados | 3/6 |
| (diário) | view UNION sob demanda | sem materialização | M | `?day=` mix | 6 |
| (triagem) | `conversation_suggestions` + UI | gerar pós-sync | M | faixas de confiança | 4/6 |

## Ação de segurança obrigatória (não-feature)

- **SEC-DUMP:** remover `postgres-volume-snapshot-*.tgz` do versionamento e adicionar ao `.gitignore`; mover para storage seguro fora do repo. Pré-requisito de qualquer versionamento público/compartilhamento. Não é feature funcional; é higiene de dados sensíveis.

## Estratégia de rollback

- **Antes/depois:** contagem por tabela origem×destino; `wc -l summaries.jsonl` × `Conversation.count`; soma `duration`.
- **Backup:** `pg_dump` do banco Rails antes de cada carga grande; reter snapshot do Repo A como baseline (em local seguro).
- **Reverter carga:** lotes transacionais (rollback do lote); restauração do `pg_dump` em corrupção ampla.
- **Validar contagem:** relatório pós-import com `imported/updated/skipped/error_lines` (de `sync_runs`).
- **Integridade referencial:** checar órfãos de FK (links sem conversa/tarefa; turnos sem conversa); CHECK de link com alvo.
- **Re-sync sem duplicidade:** rodar 2× → `imported=0`, `updated=N`, count estável, `UNIQUE(conversation_id, seq)` intacto.
