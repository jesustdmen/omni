# Omni — Decisões de contrato da Fase 5 (UI de conversa) — fronteira inicial

> **Contrato inicial de fronteira. NÃO é implementação.** Nenhuma migration/model/serviço/UI de
> turnos foi criada. A F5 (e qualquer fatia de índice de turnos) aguarda autorização explícita.
> Base obrigatória: [ADR-021](adr/ADR-021-lazy-load-turnos-via-indice-offsets.md) (lazy-load por índice
> de offsets), [ADR-012](adr/ADR-012-markdown-sanitization.md) (sanitização), [ADR-013](adr/ADR-013-personal-conversations.md)
> (conversas pessoais), [ADR-008](adr/ADR-008-output-normalized-contract.md) (consumo de `output/normalized/`).

> **Atualização (2026-06-17):** a **fatia de infraestrutura** já foi entregue (pré-F5): tabelas
> `turn_sources` + `conversation_turn_refs` (só ponteiros), `Sync::BuildConversationTurnRefs`,
> `ConversationTurns::LazyLoader` e rake `sync:turn_refs`. Build real: 129.482 refs, **covered
> 1635/1635**, sem persistir conteúdo. **A F5 consome o `LazyLoader`** — falta a UI + render
> sanitizado (ADR-012). Ver `DELIVERY_LOG.md`.

## F5.1 — render read-only de turnos (ENTREGUE 2026-06-18)
Fatia mínima entregue (consome o `LazyLoader`; **sem** markdown/scorer/UI rica):
- **Render read-only** de turnos em `/conversations/:id` (dentro do `show`, **sem rota/controller/policy novos**); `Conversations::TurnListComponent` (ViewComponent).
- **Paginação** `TURNS_PER_PAGE = 50` via `turn_page`; `limit` **fixo** e `offset` derivado da página (sem `limit/offset` do usuário).
- Exibe `role` (allowlist), `timestamp`, **texto auto-escapado** (`white-space: pre-wrap`), `tool`/`tool_input` como **texto em `<pre>`** (`JSON.pretty_generate` com `rescue` + truncamento); estados `:ok/:empty/:stale/:not_found` e `mismatched` com aviso.
- **Decisão `personal` = b1:** se `conversation.personal`, **não chama o loader** e exibe aviso "conversa pessoal — conteúdo oculto nesta fase". **Sem dono/`user_id`; ADR-013 inalterado; ownership não muda nesta fatia.**
- **Segurança:** somente auto-escape do ERB; **proibidos** `html_safe`/`raw`/`<%==`/`simple_format`/`sanitize` (com grep-guard de teste); **sem markdown** (adiado F5.2); **sem auto-link**; **`source_file` oculto**; **CSP restrita** habilitada (nonce p/ importmap).
- **Limitação conhecida:** `text`/`tool_input` ainda **não** são redigidos (só `source_file` é, e fica oculto) — ampliar redação de PII = follow-up.
- **Validação real:** conversa de 177 turnos → loader `:ok`, render 50/página ("Página 1 de 4"), sem `<script>`/`onerror=` crus, sem vazar path/`Users`.
- **F5.1.1 (`a01efbd`):** correção do artefato ERB `). %>` (comentário do componente continha `<%= %>`) + **cor de badge por role** via allowlist (`ROLE_TONES`); render read-only mantido.
- **F5.1.2:** consolidação documental + **persistência do mount `/normalized:ro`** no `.devstack/up.sh` (runtime reproduzível); addendum ao ADR-013 (`personal` boolean + b1). Sem mudança de comportamento.
- **F5.1.3:** `sync_runs/show` deixa de exibir o caminho cru de `source_file` — helper `safe_basename` mostra só o nome do arquivo (sem `/normalized`//`/tmp`//`/home`//`C:\Users`//`file://`). *(PII em `text`/`tool_input` entregue depois, na F5.1.5.)*
- **F5.1.4 (DB-only):** limpeza transacional dos resíduos sintéticos de auditoria no DB **dev** (9 refs + 3 turn_sources `/tmp` + 3 conversas `tXSS*` + 3 sync_runs `/tmp`; backup gitignored). DB dev fiel ao real (1635/1/129482/5/1, órfãs 0); conversa real e loader `:ok` (177) preservados. Sem alterar código/schema.
- **F5.1.5 (`821f495`):** **redação de PII/segredos** em `text`/`tool_input` no render, via `ConversationTurns::PiiRedactor` (conservador/idempotente) aplicado em `TurnListComponent#turn_text`/`#tool_input_text` **antes do truncamento**; cobre e-mail, `Bearer`, `token|api_key|secret|password|access_token|refresh_token`, paths `Users|home` (Unix/Windows/`file://`) → `<EMAIL>`/`<SECRET>`/`<USER>`. ERB auto-escape mantido; `tool_input` segue em `<pre>`; sem markdown. **Limitação:** não exaustivo (sem segredos não-rotulados; sem CPF/telefone/IP); conteúdo-fonte read-only inalterado; redação só no render.

## Status da Fase 5 (P0, 2026-06-18)
- **F5.1 = sub-entrega CONCLUÍDA** (read-only); **a Fase 5 permanece ABERTA**. Suíte atual: **225 runs / 811 assertions / 0**; rubocop 125/0; brakeman 0; bundler-audit 0.
- **Pendências F5.2+:** markdown sanitizado (CV-07) + code blocks, syntax highlight, busca, virtualização, modal vincular (Ctrl+L, UI-09), criar tarefa de conversa (UI-10), dashboard (UI-01), aba Conversas rica (UI-04). *(Redação de PII em `text`/`tool_input` entregue na F5.1.5.)*
- **Produção (F7) não iniciada** — readiness consolidado no `PROJECT_STATUS.md` (seção "Readiness de produção"). Exposição externa/multi-tenant exige F7 + isolamento por owner/tenant (ADR-014) + redação de PII.

## Fronteiras da Fase 5
1. **A F5 depende do ADR-021** — a localização de turnos segue o lazy-load por índice de offsets
   (chave `thread_id`; ponteiros, não conteúdo; `seek` + `readline`; validar `thread_id` da linha lida).
2. **A F5 abrirá turnos sob demanda** (ao abrir uma conversa), lendo apenas as linhas daquela conversa.
3. **A F5 não deve fazer full-scan** do `sessions.jsonl` por request.
4. **A F5 deve renderizar com sanitização** conforme o **ADR-012** (markdown server-side; payload XSS
   neutralizado).
5. **A F5 deve tratar markdown, `tool_input`, paths e payloads como não confiáveis** (`tool_input`
   nunca como HTML; `raw_source_file`/paths com usuário **omitidos ou redigidos `<USER>`**).
6. **A F5 deve respeitar `conversation.personal`** (ADR-013) ao expor conteúdo.
7. **A F5 não deve alterar importers.**
8. **A F5 não deve criar scorer/auto-link** (isso é F4 v1).

## Fora desta fronteira (a decidir/implementar depois, sob autorização)
- Esquema concreto do índice de turnos (`conversation_turn_refs`), builder/rebuilder, rake de indexação.
- Modelo de render (componente de turno, markdown→HTML seguro, exibição de `tool_input`/arquivos).
- Paginação de conversas muito longas; ordenação por `seq`.
- Tags de conversa, triagem, diário (F6).

## Critérios de aceite (quando a F5 for implementada)
- Abrir conversa lê **só** as linhas da thread (sem full-scan); turnos **ordenados**.
- **Payload malicioso neutralizado** (teste de XSS — ADR-012); `tool_input` nunca renderizado como HTML.
- Paths/PII **redigidos/omitidos**; `personal` respeitado.
- Sem alteração de importers; sem execução de sync; sem scorer/auto-link.
