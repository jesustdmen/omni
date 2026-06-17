# ADR-017 — CNPJ opcional em Client

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
Hoje clients.cnpj é NOT NULL + UNIQUE. O mockup mostra cliente "Interno" com CNPJ "—", incompatível com NOT NULL.

## Decisão
Tornar cnpj opcional (nullable); manter unicidade apenas quando presente via partial unique index (WHERE cnpj IS NOT NULL).
- Normalizar string vazia para NULL na migração.

## Alternativas consideradas
- Manter NOT NULL — bloqueia cliente interno/sem CNPJ.
- Remover unicidade — permite CNPJ duplicado.

## Consequências positivas
- Suporta cliente interno; preserva integridade de CNPJ real.

## Consequências negativas
- Migração precisa relaxar a constraint existente.

## Riscos
- Dados legados com CNPJ vazio/"" vs NULL — normalizar na migração ("" → NULL).

## Critérios de aceite
- Cliente sem CNPJ é criado; dois clientes com mesmo CNPJ não-nulo são rejeitados.

## O que NÃO fazer
- Não dropar a unicidade; usar partial unique.
