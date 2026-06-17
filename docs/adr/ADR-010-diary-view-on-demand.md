# ADR-010 — Diário por view/consulta sob demanda

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
O diário mistura task/convo/time no eixo do tempo (GET /api/diary?day= → ActivityItem[]). O volume por dia é pequeno.

## Decisão
View/consulta sob demanda (UNION de tasks/conversations/time_entries por dia). Não materializar activity_items no MVP.

## Alternativas consideradas
- Tabela materializada activity_items — duplica dados, exige sincronização, complexidade prematura.

## Consequências positivas
- Sem duplicação nem job de manutenção; sempre consistente.

## Consequências negativas
- Consultas mais complexas (UNION/ordenação).

## Riscos
- Performance se a janela do diário crescer muito — improvável no perfil diário.

## Critérios de aceite
- ?day= retorna o mix ordenado por hora sem tabela dedicada.

## O que NÃO fazer
- Não criar activity_items "para escalar" sem evidência de gargalo.
