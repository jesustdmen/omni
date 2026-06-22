# ADR-016 — Escopo dos campos novos de Task no MVP

## Status
Aceito — 2026-06-16 (Fase 0). **Addendum 2026-06-22**: checklist (PB-004b) e código legível de tarefa (PB-014) reabertos e entregues — ver Addendum ao fim.

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

---

## Addendum — 2026-06-22 (Produto Operacional)

A decisão original adiou vários campos para v1. Dois deles foram **reabertos e entregues** na trilha Produto Operacional, por decisão do PO:

- **Checklist (subtarefas) — PB-004b** (2026-06-21): `checklist_items` por tarefa (ver `DELIVERY_LOG`).
- **Código legível de tarefa — PB-014** (2026-06-22): `tasks.code_number` (bigint) gerado por **sequence do PostgreSQL** (`DEFAULT nextval`; concorrência segura no banco, nunca `maximum+1`), exibido como **`TSK-000001`** (`Task#code` = `TSK-%06d`). Backfill determinístico das tarefas existentes (`created_at ASC, id ASC`); `NOT NULL` + índice **unique**; `attr_readonly` e fora dos strong params (não atribuível pela aplicação). **Identificador operacional, não substitui a PK** — as URLs continuam usando UUID; **não** há rota/lookup por código nesta fatia. Exclusão **não reutiliza** código (gaps após rollback/exclusão são aceitáveis). Exibido na lista/detalhe de tarefas, busca global, links em demandas/conversas/apontamentos e selects (`TSK-000001 — Título`); busca por código (completo ou número, case-insensitive) em OR com a busca por texto.

**Ainda fora de escopo** (seguem em v1/roadmap): tags, responsável/assignee, due_date, estimated_hours; rota/lookup público por código.

**Mantido:** a prioridade integridade/testabilidade > UI; nada quebra a paridade. Gerações concorrentes não duplicam (garantia da sequence + índice unique, com teste).
