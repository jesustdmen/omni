# ADR-005 — Solid Queue para background jobs

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O import de 240 MB e o scorer não podem rodar no request. O ambiente alvo é Windows local (pipeline exige APPDATA; Postgres local via docker-compose).

## Decisão
Solid Queue (fila em PostgreSQL, nativo no Rails 8, sem Redis).

## Alternativas consideradas
- Sidekiq — maduro, mas exige Redis (infra extra no host Windows).
- GoodJob — alternativa Postgres viável; Solid Queue é o default mantido pela equipe Rails.

## Consequências positivas
- Sem Redis; um serviço a menos no local; transacional com o banco principal.

## Consequências negativas
- Menos ecossistema/observabilidade que Sidekiq.

## Riscos
- Throughput de fila em Postgres para jobs muito grandes — aceitável no perfil local single-user.

## Critérios de aceite
- SyncConversationsJob enfileira e processa fora do ciclo de request.

## O que NÃO fazer
- Não introduzir Redis/Sidekiq no MVP sem necessidade medida.
