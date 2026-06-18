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
