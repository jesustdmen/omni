# ADR-015 — Estratégia de multi-ambiente / homologação

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O Repo A troca prod/hml em runtime por sessão via AsyncLocalStorage + Proxy no db, e clona prod→hml com pg_dump|psql por endpoint admin. É um workaround de Node, com execução de comando externo e credenciais em env var.

## Decisão
Dropar o runtime-switch. Usar ambientes de deploy separados (RAILS_ENV/bancos distintos).
- Não portar AsyncLocalStorage/Proxy de DB.
- Homologação será banco/ambiente separado.
- Se necessário, clone será rake task segura, não endpoint HTTP.

## Alternativas consideradas
- Portar runtime-switch (connects_to/Current) — replica complexidade; reabre risco de comando externo via HTTP.
- Manter endpoint de clone — superfície de injeção/credencial.

## Consequências positivas
- Menos superfície de risco; modelo de ambiente padrão Rails.

## Consequências negativas
- Perde a troca de ambiente "pela sessão" (se isso for requisito real).

## Riscos
- Confirmar que troca de ambiente em runtime não é requisito de produto (era conveniência).

## Critérios de aceite
- Homologação obtida por rake task/deploy separado; nenhum endpoint faz spawn de pg_dump.

## O que NÃO fazer
- Não recriar o Proxy de DB. Não expor clone de banco como rota HTTP.
