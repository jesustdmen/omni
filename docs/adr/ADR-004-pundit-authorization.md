# ADR-004 — Pundit para autorização

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O Repo A só tem requireAuth/requireAdmin. O mockup introduz conversa pessoal e dono de conversa (status: personal, userId), exigindo autorização por recurso.

## Decisão
Pundit, com policies por recurso (conversas/turnos por user_id; domínio de trabalho compartilhado no MVP, ver ADR-014).

## Alternativas consideradas
- CanCanCan — DSL centralizada; preferência por policies explícitas/testáveis.
- Sem framework (checagens ad-hoc) — repete o gap atual.

## Consequências positivas
- Policies testáveis isoladamente; segregação de conversa pessoal.

## Consequências negativas
- Boilerplate de policy por recurso.

## Riscos
- Esquecer authorize em controller — mitigar com verify_authorized.

## Critérios de aceite
- Conversa personal de um usuário não é visível/listável por outro (policy spec verde).

## O que NÃO fazer
- Não espalhar checagens de role pelos controllers.
