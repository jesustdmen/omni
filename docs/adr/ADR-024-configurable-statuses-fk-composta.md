# ADR-024 — Status configurável (Tarefas/Projetos) com FK composta

## Status
Aceito — 2026-06-24 (PB-018).

## Contexto
Até a PB-018, o `status` de Tarefas e Projetos era uma **lista fixa** embutida no
código (Task: `enum` Rails; Project: `STATUSES`/`STATUS_LABELS`) e travada no banco
por **CHECK constraint** (`tasks_status_check`, `projects_status_check`). O PO pediu
status **configuráveis** (nome, chave, cor, ordem, ativo, finalizador), sem perder a
garantia de integridade no banco. Demanda permanece com status **fixo**
(`pending`/`converted`) — fora de escopo desta entrega.

O CHECK fixo é incompatível com keys criadas pelo usuário (bloquearia novos status).
Era preciso substituí-lo por uma garantia que ainda fosse do **banco**, não só do app.

## Decisão
Criar a tabela `configurable_statuses` (uuid; `entity_type` ∈ {task, project},
`key`, `name`, `color`, `position`, `active`, `final`; índice **único (entity_type, key)**).

A coluna `status` (string) é **mantida** em `tasks`/`projects` guardando a **key**
(menor impacto; URLs/filtros/dados inalterados). A integridade migra para uma
**FK composta**:

- Adicionada coluna discriminadora constante por linha: `tasks.status_entity = 'task'`
  e `projects.status_entity = 'project'` (travadas por CHECK + `attr_readonly`).
- **FK composta** `(status_entity, status) → configurable_statuses(entity_type, key)`
  com **ON DELETE RESTRICT** e ON UPDATE CASCADE.

Isso garante no banco: (a) só keys existentes; (b) task referencia status de 'task'
e project de 'project' (entidade correta); (c) status **em uso não é excluível**
(RESTRICT). Os CHECKs de lista fixa de tasks/projects foram **removidos**.

Camada de app (complementar, não substituta da FK):
- Validação `status_is_assignable`: status deve existir para a entidade; valores
  **novos** exigem status **ativo**; valor já persistido e inalterado é aceito mesmo
  inativo (não quebra registros antigos).
- Exclusão na UI bloqueada com mensagem amigável quando `in_use?` (a FK é a rede final).
- `finalizador` (`final`) afeta **apenas** filtros/exibição — sem regra comercial,
  cálculo, fechamento ou bloqueio de edição.

## Alternativas consideradas
- **Só validação no app (sem FK), removendo o CHECK:** menor migration, mas uma
  escrita fora do app (console/SQL) gravaria key inválida e o bloqueio de exclusão
  dependeria só do Rails. **Rejeitada** pelo PO (exigência de garantia no banco).
- **Trocar `status` por `status_id` (FK simples a um id):** mais "normalizado", mas
  alto impacto (migração de todos os filtros/links/dados de `status`-string) e perda
  de legibilidade do valor. **Rejeitada** por custo/risco desproporcional.
- **Manter enum/CHECK e só adicionar labels:** não atende "configurável". Rejeitada.

## Consequências positivas
- Integridade real no banco (existência + entidade correta + RESTRICT), além do app.
- Impacto baixo: `status` continua sendo a key string; só a fonte de rótulos/opções muda.
- Rótulos PT-BR e cores passam a ser editáveis sem deploy.

## Consequências negativas / limites
- A `key` é **imutável** após criada (é referenciada pela FK) — renomear é via `name`.
- Reatribuição em massa de registros entre status **não** está nesta entrega (o
  usuário inativa o status ou move os registros manualmente antes de excluir).
- Custo bcrypt e demais itens não relacionados não são afetados.

## Critérios de aceite
- Migration cria a tabela + seed dos status atuais; FK composta criada; CHECKs antigos
  removidos; registros existentes seguem válidos.
- Excluir status em uso é bloqueado (app + FK); status livre é excluível.
- Status inativo some dos selects de novos registros, mas o valor atual de um registro
  continua exibível/editável.
- Demanda mantém status fixo.

## O que NÃO fazer
- Não tornar Demanda configurável (fora de escopo).
- Não usar `final` para disparar regra de negócio/fechamento.
- Não permitir editar `key`/`entity_type` de um status existente.
