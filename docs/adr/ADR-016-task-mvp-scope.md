# ADR-016 — Escopo dos campos novos de Task no MVP

## Status
Aceito — 2026-06-16 (Fase 0).

## Contexto
Schema atual de tasks: client_id, project_id, title, description, type, status. O mockup mostra checklist, tags, responsável, prazo, estimativa, código TSK-XXX — nenhum existe hoje. Prioridade declarada: integridade/testabilidade > UI.

## Decisão
MVP = paridade + counter caches. Adicionar apenas conversation_count e last_conversation_at (necessários ao vínculo). Adiar para v1: tags, responsável/assignee, due_date, estimated_hours, checklist (subtarefas), código legível.

## Alternativas consideradas
- Implementar todos os campos do mockup no MVP — infla escopo, atrasa paridade, sem suporte no domínio atual.
- Nenhum campo novo — quebra o vínculo (counters são necessários).

## Consequências positivas
- Paridade rápida e testável; vínculo funciona.

## Consequências negativas
- Detalhe de tarefa no MVP fica visualmente mais pobre que o mockup.

## Riscos
- Expectativa de UI x entrega — alinhar que o mockup é alvo de v1.

## Critérios de aceite
- tasks no MVP = colunas atuais + conversation_count + last_conversation_at.

## O que NÃO fazer
- Não criar checklist/tags/assignee no MVP. Não bloquear paridade por campos de v1.

## Validação futura
- tags/assignee/due_date/estimated_hours/checklist/código legível entram na v1/roadmap.
