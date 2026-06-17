# ADR-008 — Rails consome output/normalized/

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O mockup decide explicitamente: o Omni não reparseia arquivo bruto; importa de output/normalized/. Saída: summaries.jsonl (1 linha/conversa, ~1,1 MB), sessions.jsonl (1 linha/turno, 240 MB), session_titles.json (thread_id→título).

## Decisão
Contrato de import = ler summaries.jsonl + session_titles.json (conversas) e sessions.jsonl (turnos, conforme ADR-009), com upsert por thread_id.

## Alternativas consideradas
- Ler ~/.claude/**, state.vscdb diretamente — reintroduz o problema que o pipeline já resolveu.
- Consumir os relatórios de 03_report — derivados, não canônicos.

## Consequências positivas
- Acoplamento ao contrato estável, não à fonte bruta.

## Consequências negativas
- Acoplamento ao layout de arquivos/diretório (mitigado por path configurável, ADR-011).

## Riscos
- Linha JSON malformada (o Repo B reconhece crash análogo em report.py, P0) — tratado na estratégia de import.

## Critérios de aceite
- Sync popula conversations a partir de summaries.jsonl + session_titles.json sem ler bruto.

## O que NÃO fazer
- Não reparsear .vscdb/.jsonl brutos. Não copiar os 240 MB para dentro do banco indiscriminadamente (ADR-009).
