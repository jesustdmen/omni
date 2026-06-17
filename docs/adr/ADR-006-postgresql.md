# ADR-006 — PostgreSQL 16 como banco principal

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
Origem e destino são PostgreSQL 16 (docker-compose `postgres:16-alpine`). Há snapshot real do volume. O modelo de dados precisa de text[], jsonb, partial unique index e GIN — todos nativos do Postgres.

## Decisão
PostgreSQL 16 como único banco (domínio + conversas + filas Solid Queue).

## Alternativas consideradas
- SQLite (default Rails 8) — não suporta bem text[]/GIN/concorrência de jobs no perfil pretendido.
- Banco separado para conversas — complexidade sem ganho no MVP.

## Consequências positivas
- Migração trivial (mesmo engine); recursos avançados disponíveis.

## Consequências negativas
- Dependência de Postgres no host local (já existente).

## Riscos
- Crescimento de conversation_turns (mitigado por ADR-009).

## Critérios de aceite
- App e jobs operam sobre um único Postgres; tipos text[]/jsonb/partial index em uso.

## O que NÃO fazer
- Não usar SQLite "para começar rápido". Não versionar dumps no repositório (ver SEC-DUMP no MIGRATION_PLAN).
