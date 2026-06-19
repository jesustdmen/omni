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

## F5.2 — markdown sanitizado no render (ENTREGUE 2026-06-18)
- **`text` vira markdown (GFM) → HTML sanitizado server-side** (ADR-012), via `ConversationTurns::MarkdownRenderer` (novo): `commonmarker 2.8.2` em modo seguro (`unsafe:false`, `escape:true`) → `Rails::HTML5::SafeListSanitizer` (allowlist) → hardening de links. **Defesa em profundidade** (parser seguro **e** sanitizer).
- **Allowlist:** tags `p br hr strong em b i del code pre blockquote ul ol li h1-h6 a table thead tbody tr th td`; atributos só `href rel target` (em `a`). **Sem** `img`/`script`/`style`/`class`/`id`/`on*`.
- **Links:** só `http`/`https`/`mailto` → `rel="nofollow noopener noreferrer"` + `target="_blank"`; demais esquemas (`javascript:`/`data:`) e âncoras vazias **viram texto**.
- **`tool_input` inalterado** (texto literal em `<pre>`, sem markdown). **PII redigida antes** do markdown. `html_safe`/`sanitize` **só** no `MarkdownRenderer` (grep-guard de componente/template mantido verde).
- **Limitação:** raw HTML perigoso é **neutralizado por escape** (texto inerte), não apagado; sem imagens (remotas/markdown); sem syntax highlight.
- **Validação:** suíte 257/966/0; rubocop 129/0; brakeman 0; bundler-audit 0; smoke real `/conversations/cd086107…` 200, markdown visível, 0 tag viva perigosa, 0 vazamento de PII.

## F5.3 — criar tarefa a partir da conversa (UI-10) (ENTREGUE 2026-06-18)
- **Rota aninhada** `conversations/:conversation_id/tasks` (`new`/`create`) → `ConversationTasksController` (novo); fecha o loop Conversa→Tarefa (antes só vínculo a tarefa existente).
- **Transação:** `Task.save!` + `ConversationLink.save!` (`primary`/`manual`, `created_by`) na mesma `transaction` → falha do link faz **rollback total** (sem tarefa órfã); counters via `after_create` do link.
- **Conversa já com `primary`:** `new` redireciona à conversa com alert; `create` com backstop pela validação `single_primary_per_conversation`; ação "Criar tarefa desta conversa" **oculta** quando há `primary`. Mantido o fluxo de vincular tarefa existente.
- **Autorização:** `authorize @conversation (show?)` + `@task (create?)` + `@link (create?)` (ADR-014; **sem policies novas**). Reusa `tasks/_form` (`url:` opcional) com título sugerido (`conversation.title` ou `"Conversa <8>"`).
- **Validação:** suíte 264/1016/0; rubocop 131/0; brakeman 0; bundler-audit 0; smoke real (gating + form + visões dos dois lados) sem mutar dados.

## F5.4 — lista de conversas acionável / status de vínculo (CV-04) (ENTREGUE 2026-06-19)
- `/conversations` ganha coluna **Vínculo** + **filtro `link`** (`none`/`primary`/`mention`); vira triagem leve. **Não carrega turnos** (LazyLoader não é chamado); **eager loading** `includes(conversation_links: :task)` só na página (`@total_count` sem includes) → sem N+1 (vínculos em 1 query).
- **Badges** via `ConversationsHelper#link_status_badge` (seguro: `content_tag`/`link_to`/`safe_join`; sem `html_safe`/`raw`/`sanitize`): sem vínculo (+ "Criar tarefa" GET → F5.3); primária linkando à task (+"+N menção"); "Menção (N)".
- **Semântica do filtro:** `none` = sem nenhum link; `primary` = ≥1 primary; `mention` = ≥1 mention (mesmo com primária). Subquery em coluna indexada (sem JOIN duplicado).
- **Fora desta fatia (segue v1/F5.5+):** inbox de triagem com lote/atalhos (UI-05), tags, arquivos alterados, dashboard, Ctrl+L, scorer, busca avançada, abas reais. Sem migration/schema/model/policy/rota.
- **Validação:** suíte 272/1047/0; rubocop 132/0; brakeman 0; bundler-audit 0; smoke real dos filtros (`primary`=1, `none`=1634, `mention`=0) sem mutar dados.

## Status da Fase 5 (P0, 2026-06-18)
- **F5.1 = sub-entrega CONCLUÍDA** (read-only); **a Fase 5 permanece ABERTA**. Suíte atual: **225 runs / 811 assertions / 0**; rubocop 125/0; brakeman 0; bundler-audit 0.
- **Pendências F5.2+:** syntax highlight, busca, virtualização, modal vincular (Ctrl+L, UI-09), criar tarefa de conversa (UI-10), dashboard (UI-01), aba Conversas rica (UI-04). *(Markdown sanitizado + code blocks entregues na F5.2; redação de PII na F5.1.5.)*
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
