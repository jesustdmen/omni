# ADR-001 — Rails monolítico + Hotwire como arquitetura base

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O Repo A já está estruturado em camadas que mapeiam 1:1 para Rails (routes→controllers→services→repositories→Drizzle). O frontend é CRUD com tabelas/filtros/paginação/dialogs/badges. O mockup é denso em navegação e atalhos de teclado (Ctrl+L, Ctrl+K, L/T/P/A/↵), não em interatividade rica de cliente. Não há realtime pesado, GraphQL ou WebSocket que justifique uma SPA.

## Decisão
Rails 8 monólito com Hotwire (Turbo Frames/Streams + Stimulus) e ViewComponent para toda a UI.

## Alternativas consideradas
- Rails API + React SPA — recria a complexidade atual (duas stacks, CORS, CSRF de SPA, cache cliente).
- Manter parte em TypeScript — divide o time, duplica auth.
- Phlex no lugar de ERB/ViewComponent — otimização prematura.

## Consequências positivas
- Uma stack, um deploy, uma linguagem de domínio.
- ViewComponents herdam os componentes isolados do Repo A (StatusBadge, TaskTypeBadge, DataTable).
- Turbo cobre navegação parcial; Stimulus cobre atalhos.

## Consequências negativas
- Interatividade muito rica (ex.: render de conversa com tool calls colapsáveis) é mais trabalhosa que em React.
- Equipe precisa de fluência em Hotwire.

## Riscos
- Subestimar a complexidade do render de conversa (mitigado por ADR-002).

## Critérios de aceite
- Decisão registrada e aceita; nenhuma dependência de bundler de SPA no MVP.

## O que NÃO fazer
- Não introduzir SPA "por garantia". Não montar API REST pública antes de haver consumidor externo.
