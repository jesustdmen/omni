# Domínios do Banco de Dados

> Visão funcional do banco do Omni por domínio. Use este documento para entender ownership dos dados, o que pode ser reconstruído e o que é registro humano real. Para detalhe estrutural de campos, chaves e constraints, ver [`DATABASE_SCHEMA_SPEC.md`](DATABASE_SCHEMA_SPEC.md).

## 1. Mapa de domínios

| Domínio | Tabelas | Natureza | Pode reconstruir automaticamente? |
|---|---|---|---|
| Identidade e acesso | `users` | Humano/sistema | Não |
| Cadastros operacionais | `clients`, `contacts`, `provider_companies`, `contracts`, `projects`, `configurable_statuses` | Humano/operacional | Não |
| Trabalho | `demands`, `tasks`, `checklist_items`, `time_entries` | Humano/operacional | Não |
| Conversas | `conversations`, `workspace_maps` | Derivado de sync + classificação humana possível | Parcialmente, com gate |
| Evidência lazy | `turn_sources`, `conversation_turn_refs` | Derivado de arquivos normalizados | Sim, com gate |
| Triagem | `conversation_triages`, `conversation_links`, `conversation_activity_drafts`, `conversation_work_blocks` | Humano/operacional sobre conversas | Não automaticamente |
| Sync | `sync_executions`, `sync_runs`, `sync_run_items`, `sync_schedules` | Operacional/auditoria | Parcialmente, com gate |
| Fila | `solid_queue_*` | Infraestrutura | Não por scripts de domínio |

## 2. Domínio de identidade

### Tabelas

- `users`

### Responsabilidade

Controla autenticação, autorização básica e rastreabilidade de ações feitas no sistema.

### Campos-chave

- `email` e `username`: identificadores únicos de login/uso.
- `role`: papel do usuário.
- `is_active`: bloqueio operacional.
- `encrypted_password` e campos de reset: gerenciados pelo Devise.

### Regras

- Não limpar em reconstrução de sync.
- Não usar usuário como critério primário de ownership de conversas enquanto o produto mantiver domínio compartilhado.

## 3. Domínio comercial/cadastral

### Tabelas

- `clients`
- `contacts`
- `provider_companies`
- `contracts`
- `projects`
- `configurable_statuses`

### Responsabilidade

Define quem é atendido, quem presta o serviço, em qual contexto comercial e qual status operacional é permitido para tarefas/projetos.

### Campos-chave

- `clients.workspace_paths`: usado para sugerir cliente a partir do workspace da conversa.
- `contracts.provider_company_id`, `contracts.client_id`, `contracts.project_id`: regra comercial de cobrança.
- `contracts.hourly_rate`: valor/hora para cálculo futuro.
- `projects.status` + `projects.status_entity`: status validado por FK composta.
- `configurable_statuses.entity_type/key`: catálogo oficial de status.

### Regras

- Dados cadastrais são preservados em qualquer reconstrução.
- Contrato não é gravado em `time_entries`; cálculo comercial resolve contrato em tempo de apuração/fechamento.
- `projects` pertencem a `clients`; apagar cliente em cascata apagaria projetos e tarefas, portanto isso nunca deve fazer parte de limpeza de conversas.

## 4. Domínio de trabalho

### Tabelas

- `demands`
- `tasks`
- `checklist_items`
- `time_entries`

### Responsabilidade

Representa o trabalho real: demanda recebida, tarefa executável, checklist e apontamento oficial de tempo.

### Campos-chave

- `demands.status`: `pending` ou `converted`.
- `tasks.code_number`: número operacional exibido como `TSK-000001`.
- `tasks.demand_id`: vínculo 1:1 com demanda convertida.
- `tasks.conversation_count` e `tasks.last_conversation_at`: contadores derivados de vínculos com conversas.
- `time_entries.task_id`: tarefa apontada.
- `time_entries.conversation_id`: evidência opcional; pode precisar ser revinculada após reconstrução.
- `time_entries.duration`: duração em segundos.
- `time_entries.is_running`: timer aberto.

### Regras

- `demands`, `tasks` e `time_entries` são registros reais e devem sobreviver à reconstrução do banco de conversas.
- Se uma conversa contaminada/ fantasma for removida e algum vínculo humano existir, a conversa não pode ser apagada sem plano de migração do vínculo.
- O usuário aceitou revincular conversas depois; isso não autoriza apagar tarefas, demandas ou apontamentos.

## 5. Domínio de conversas

### Tabelas

- `conversations`
- `workspace_maps`

### Responsabilidade

Armazena metadados de conversas importadas do pipeline normalizado e resolve workspace para contexto legível.

### Campos-chave

- `conversations.thread_id`: chave canônica apenas para fontes conversacionais.
- `conversations.source`: fonte conversacional vencedora.
- `conversations.workspace_hash`: workspace de origem.
- `conversations.personal`: exclui conversa de triagem de trabalho, blocos e cálculo de tempo.
- `workspace_maps.workspace_hash/folder`: resolve hash para pasta.

### Regra canônica pós-incidente

Telemetria não é conversa. As fontes `chat_editing_state`, `agent_sessions` e `chat_session_index` podem existir no output normalizado como evidência/índice auxiliar, mas não podem criar `Conversation`, mesclar `Conversation` nem gerar `conversation_turn_refs`.

### Regras de reconstrução

- Conversas derivadas exclusivamente de telemetria são candidatas a remoção se não tiverem vínculo humano.
- Conversas contaminadas por telemetria devem ser reparadas via reimport pelo código corrigido.
- `thread_id` permanece canônico, mas restrito à allowlist conversacional definida em `Sync::Sources`.

## 6. Domínio de evidência lazy

### Tabelas

- `turn_sources`
- `conversation_turn_refs`

### Responsabilidade

Permite renderizar conversa por lazy-load a partir dos arquivos normalizados, armazenando ponteiros e não o conteúdo completo.

### Campos-chave

- `turn_sources.content_hash`, `source_mtime`, `size_bytes`: fingerprint da fonte.
- `turn_sources.status`: integridade do índice.
- `conversation_turn_refs.turn_source_id`: arquivo indexado.
- `conversation_turn_refs.conversation_id`: conversa de destino.
- `conversation_turn_refs.line_no` e `byte_offset`: ponteiro de leitura.
- `conversation_turn_refs.role`: papel do turno.

### Regras

- Pode ser rebuildado após estabilizar `conversations`.
- Não deve indexar telemetria.
- Rebuild deve preservar a estratégia lazy: ponteiros no banco, conteúdo lido sob demanda.

## 7. Domínio de triagem

### Tabelas

- `conversation_links`
- `conversation_triages`
- `conversation_activity_drafts`
- `conversation_work_blocks`

### Responsabilidade

Registra interpretação humana ou assistida da conversa: vínculo com tarefa, decisão de triagem, rascunhos de atividades e blocos de trabalho/tempo.

### Campos-chave

- `conversation_links.task_id`: vínculo com tarefa real.
- `conversation_links.link_type`: `primary` ou `mention`.
- `conversation_triages.status`: decisão da triagem.
- `conversation_triages.confirmed_client_id/project_id`: confirmação manual.
- `conversation_activity_drafts.status/source`: rascunhos manuais ou IA local.
- `conversation_work_blocks.kind`: `execution` ou `gap`.
- `conversation_work_blocks.status`: `draft`, `confirmed` ou `discarded`.
- `conversation_work_blocks.gap_kind`: classificação obrigatória para gap confirmado.
- `conversation_work_blocks.duration_seconds`: subtotal validável em segundos.

### Regras

- Triagem é dado humano/operacional. Não apagar automaticamente durante limpeza de sync.
- Conversa pessoal (`personal=true`) não participa de blocos de trabalho, cálculo de tempo, tarefas ou apontamentos.
- `conversation_work_blocks` não são `time_entries`; promoção para apontamento oficial ainda exige contrato próprio.
- `day_period` em `conversation_work_blocks` é classificatório/visual, não a unidade canônica do cálculo de tempo.

## 8. Domínio de sync

### Tabelas

- `sync_executions`
- `sync_runs`
- `sync_run_items`
- `sync_schedules`

### Responsabilidade

Controla execução, auditoria e agendamento da sincronização de conversas.

### Campos-chave

- `sync_executions.status/current_step`: estado agregado da execução.
- `sync_executions.pipeline_exit_code/pipeline_summary`: resultado do pipeline nativo.
- `sync_runs.imported/updated/skipped/error_lines`: contadores de importação.
- `sync_run_items.reason/raw_excerpt`: auditoria de linhas ignoradas/erro.
- `sync_schedules.enabled`: liga/desliga agendamento.
- `sync_schedules.interval_minutes`: frequência.

### Regras

- Durante incidente de integridade, `sync_schedules.enabled=false`.
- `sync_runs` pode registrar telemetria ignorada como `skipped` sem degradar status quando isso é comportamento esperado.
- Conflito entre famílias conversacionais deve degradar para `partial`, porque indica anomalia real.

## 9. Domínio de fila

### Tabelas

- `solid_queue_jobs`
- `solid_queue_ready_executions`
- `solid_queue_scheduled_executions`
- `solid_queue_claimed_executions`
- `solid_queue_blocked_executions`
- `solid_queue_failed_executions`
- `solid_queue_processes`
- `solid_queue_pauses`
- `solid_queue_recurring_tasks`
- `solid_queue_recurring_executions`
- `solid_queue_semaphores`

### Responsabilidade

Infraestrutura de jobs assíncronos.

### Regras

- Não confundir falha de fila com falha de domínio.
- Não limpar junto com conversas sem runbook operacional.
- Jobs podem ser reexecutados/recriados, mas isso deve ser tratado como operação de infraestrutura.

## 10. Política para o incidente atual

Antes da reconstrução:

1. Garantir backup `pg_dump`.
2. Confirmar `origin/main` com a correção `e0b6687`.
3. Confirmar `SyncSchedule.enabled=false`.
4. Rodar `sync:integrity_report`.
5. Validar que fantasmas/contaminadas seguem com zero vínculo humano.

Durante a reconstrução:

1. Reimportar pelo código corrigido.
2. Reparar conversas reais contaminadas.
3. Remover somente fantasmas sem vínculo humano.
4. Rebuildar `conversation_turn_refs`.
5. Validar contagens.

Depois da reconstrução:

1. Smoke da lista de conversas.
2. Smoke de conversa com turnos.
3. Smoke de triagem.
4. Smoke de tarefa, demanda e time entry existentes.
5. Religar `SyncSchedule` somente após validação.
