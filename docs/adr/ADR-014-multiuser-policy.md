# ADR-014 — Modelo preparado para multiusuário, domínio compartilhado no MVP

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O domínio de trabalho do Repo A é global (tasks/clients não têm user_id). O mockup atribui dono a conversas (userId) e "responsável" a tarefas (campo de UI, não de schema).

## Decisão
Modelo preparado, operação single-tenant no MVP: conversations.user_id desde já (dono); domínio de trabalho permanece compartilhado (sem user_id em tasks/clients no MVP). Autorização multiusuário plena (tenancy por usuário no domínio) → roadmap.

## Alternativas consideradas
- Multitenancy completa agora — retrofit caro e desnecessário para o uso atual.
- Single-user puro (sem user_id) — retrofit futuro caríssimo.

## Consequências positivas
- Conversa pessoal funciona; custo baixo; porta aberta para multiusuário.

## Consequências negativas
- Inconsistência transitória (conversa tem dono, tarefa não).

## Riscos
- "Responsável" da tarefa (mockup) sem coluna — fica em ADR-016 (v1).

## Critérios de aceite
- conversations.user_id populado no import; domínio de trabalho acessível a usuários autenticados.

## O que NÃO fazer
- Não adicionar user_id a todo o domínio "por precaução". Não prometer isolamento multiusuário no MVP.

## Validação futura
- Tenancy de domínio fica no roadmap.
