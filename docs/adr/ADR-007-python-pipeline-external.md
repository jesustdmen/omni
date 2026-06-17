# ADR-007 — Pipeline Python permanece externo no MVP

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
Os ~800 linhas de 9 parsers + reconstrução de patch JSONL não têm testes (dívida P1 reconhecida pelo próprio Repo B). O contrato de saída é estável (thread_id, source, schema canônico).

## Decisão
Manter o pipeline Python externo e inalterado no MVP. O Rails não reparseia arquivo bruto.

## Alternativas consideradas
- Portar parsers para Ruby agora — reescrita cega de ativo crítico sem testes (risco altíssimo).
- Reescrever o viewer em Rails — fora de escopo; viewer não é a UI final.

## Consequências positivas
- Zero risco de corromper histórico; reuso de parser validado em 129k mensagens reais.

## Consequências negativas
- Dependência de Python/venv no host; duas linguagens no projeto.

## Riscos
- Versionamento de schema do JSONL inexistente (dívida P3 do Repo B) — endereçado antes da Fase 3.

## Critérios de aceite
- Rails consome apenas output/normalized/; pipeline Python não é tocado.

## O que NÃO fazer
- Não portar parser sem o corpus de caracterização. Não alterar `pipeline/`.
