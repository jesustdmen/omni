# Especificação do Banco de Dados

> Fonte técnica de referência para a estrutura persistida do Omni. Base: `db/schema.rb` versão `2026_07_03_120000`, com a correção de sync publicada em `e0b6687`. Este documento descreve a estrutura; não autoriza limpeza, migração ou alteração de dados.

## 1. Regras de integridade para operações de dados

### 1.1. Domínio humano nunca é descartável automaticamente

As tabelas abaixo contêm registros operacionais reais, criados ou validados por uso humano. Elas **não** podem ser apagadas em reconstruções de sync:

- `clients`
- `contacts`
- `provider_companies`
- `contracts`
- `projects`
- `demands`
- `tasks`
- `checklist_items`
- `time_entries`
- `conversation_links`
- `conversation_triages`
- `conversation_activity_drafts`
- `conversation_work_blocks`
- `users`
- `configurable_statuses`

Racional: mesmo sem produção formal, já existem lançamentos reais de demanda, tarefa e apontamento. Perder vínculos com conversa é aceitável e reparável; perder demanda, tarefa ou apontamento não é.

### 1.2. Domínio derivado de sync pode ser reconstruído com gate

As tabelas abaixo são derivadas da coleta/importação de conversas e podem ser reconstruídas somente com backup, relatório read-only e autorização explícita:

- `conversations`
- `conversation_turn_refs`
- `turn_sources`
- `workspace_maps`
- `sync_runs`
- `sync_run_items`
- `sync_executions`
- `sync_schedules`

Observação: `sync_schedules` é operacional; pode ser ligado/desligado, mas não deve ser apagado sem necessidade.

### 1.3. Cascades perigosos

Algumas FKs têm `on_delete: :cascade`. Isso é correto para integridade, mas perigoso em limpeza manual:

- Apagar `conversations` apaga `conversation_links`, `conversation_triages`, `conversation_activity_drafts`, `conversation_work_blocks` e `conversation_turn_refs`.
- Apagar `tasks` apaga `checklist_items`, `conversation_links` e `time_entries`.
- Apagar `clients` apaga `contacts`, `projects` e `tasks`.

Regra operacional: limpeza de incidente de sync deve excluir somente conversas sem vínculo humano, nunca tarefas, demandas, apontamentos ou clientes.

## 2. Tabelas de domínio operacional

### 2.1. `users`

Usuários autenticados do Omni.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | bigint | sim | Chave primária. |
| `email` | string | sim | E-mail único usado pelo Devise. |
| `username` | string | sim | Nome de usuário único. |
| `encrypted_password` | string | sim | Senha criptografada pelo Devise. |
| `role` | string | sim | Papel do usuário; default `user`. |
| `is_active` | boolean | sim | Indica se o usuário está ativo. |
| `reset_password_token` | string | não | Token de recuperação de senha. |
| `reset_password_sent_at` | datetime | não | Data de emissão do token. |
| `remember_created_at` | datetime | não | Controle Devise de sessão persistente. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: `email` único, `username` único, índices por `role`, `is_active`, `reset_password_token`.

### 2.2. `clients`

Clientes atendidos.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `name` | string | sim | Razão social ou nome principal. |
| `trade_name` | string | não | Nome fantasia. |
| `cnpj` | string | não | CNPJ; único quando informado. |
| `status` | string | sim | Estado do cliente; default `active`. |
| `phone` | string | não | Telefone. |
| `address` | string | não | Endereço. |
| `workspace_paths` | text[] | sim | Caminhos usados para sugerir cliente por workspace. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: CNPJ único parcial, índice por `name`, `created_at` e GIN em `workspace_paths`.

### 2.3. `contacts`

Contatos vinculados a clientes.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `client_id` | uuid | sim | Cliente dono do contato. |
| `name` | string | sim | Nome do contato. |
| `email` | string | sim | E-mail. |
| `phone` | string | não | Telefone. |
| `position` | string | não | Cargo/função. |
| `is_primary` | boolean | sim | Indica contato principal. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK para `clients` com cascade; índice único parcial garante no máximo um contato principal por cliente.

### 2.4. `provider_companies`

Empresas prestadoras.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `name` | string | sim | Razão social ou nome principal. |
| `trade_name` | string | não | Nome fantasia. |
| `cnpj` | string | não | CNPJ; único quando informado. |
| `email` | string | não | E-mail. |
| `phone` | string | não | Telefone. |
| `address` | string | não | Endereço. |
| `active` | boolean | sim | Indica se pode ser usada em contratos. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: CNPJ único parcial e índice por `name`.

### 2.5. `contracts`

Contratos comerciais entre prestadora, cliente e, opcionalmente, projeto.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `provider_company_id` | uuid | sim | Prestadora contratada. |
| `client_id` | uuid | sim | Cliente atendido. |
| `project_id` | uuid | não | Projeto específico, quando aplicável. |
| `modality` | string | sim | Modalidade; hoje fixada em `hourly`. |
| `hourly_rate` | decimal | não | Valor/hora. |
| `status` | string | sim | `draft`, `active`, `suspended` ou `ended`. |
| `start_date` | date | sim | Início de vigência. |
| `end_date` | date | não | Fim de vigência. |
| `active` | boolean | sim | Flag operacional. |
| `notes` | text | não | Observações. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FKs para prestadora e cliente com restrict; projeto com nullify; CHECK de período, status e modalidade.

### 2.6. `projects`

Projetos de cliente.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `client_id` | uuid | sim | Cliente dono do projeto. |
| `name` | string | sim | Nome do projeto. |
| `description` | text | não | Descrição. |
| `status` | string | sim | Key configurável da entidade `project`. |
| `status_entity` | string | sim | Sempre `project`, usado na FK composta. |
| `start_date` | date | não | Início planejado/real. |
| `end_date` | date | não | Fim planejado/real. |
| `budget` | string | não | Orçamento textual. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK para `clients` com cascade; FK composta para `configurable_statuses(entity_type,key)`.

### 2.7. `tasks`

Tarefas operacionais.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `code_number` | bigserial | sim | Número sequencial usado para gerar `TSK-000001`. |
| `client_id` | uuid | sim | Cliente da tarefa. |
| `project_id` | uuid | não | Projeto associado. |
| `demand_id` | uuid | não | Demanda convertida em tarefa. |
| `title` | string | sim | Título. |
| `description` | text | não | Descrição. |
| `type` | string | sim | STI/tipo operacional da tarefa. |
| `status` | string | sim | Key configurável da entidade `task`. |
| `status_entity` | string | sim | Sempre `task`, usado na FK composta. |
| `conversation_count` | integer | sim | Contador de conversas primárias não pessoais. |
| `last_conversation_at` | datetime | não | Última conversa vinculada. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: `code_number` único; `demand_id` único parcial; FK para cliente cascade; FK para demanda restrict; projeto nullify; status por FK composta.

### 2.8. `checklist_items`

Itens de checklist de tarefa.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `task_id` | uuid | sim | Tarefa dona do item. |
| `content` | text | sim | Texto do item. |
| `completed` | boolean | sim | Indica conclusão. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK para `tasks` com cascade.

### 2.9. `demands`

Demandas antes da conversão em tarefa.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `client_id` | uuid | não | Cliente associado, se conhecido. |
| `title` | string | sim | Título. |
| `description` | text | não | Descrição. |
| `origin` | string | sim | Origem da demanda. |
| `priority` | string | sim | Prioridade. |
| `status` | string | sim | `pending` ou `converted`. |
| `converted_at` | datetime | não | Momento de conversão em tarefa. |
| `observations` | text | não | Observações. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: cliente com nullify; índice por status, prioridade e criação.

### 2.10. `time_entries`

Apontamentos oficiais de tempo. Estes registros são humanos/operacionais e não podem ser removidos por reconstrução de conversas.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `task_id` | uuid | sim | Tarefa apontada. |
| `conversation_id` | uuid | não | Conversa usada como evidência, quando houver. |
| `date` | date | sim | Dia operacional do apontamento. |
| `start_time` | timestamptz | sim | Início. |
| `end_time` | timestamptz | não | Fim; ausente enquanto timer está rodando. |
| `duration` | integer | sim | Duração em segundos. |
| `is_running` | boolean | sim | Indica timer em aberto. |
| `description` | text | não | Descrição do trabalho. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK para `tasks` com cascade; índice único parcial impede mais de um timer aberto por tarefa; `conversation_id` indexado, mas sem FK declarada no schema atual.

## 3. Tabelas de conversas, triagem e evidência

### 3.1. `conversations`

Metadados de conversas importadas de fontes conversacionais.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `thread_id` | text | sim | Identidade canônica da conversa, restrita a fontes conversacionais. |
| `source` | text | não | Fonte conversacional vencedora. Telemetria não deve persistir aqui. |
| `session_id` | text | não | Identificador de sessão vindo da origem. |
| `workspace_hash` | text | não | Hash do workspace. |
| `title` | text | não | Título. |
| `first_ts` / `last_ts` | timestamptz | não | Período da conversa. |
| `message_count` | integer | sim | Total de mensagens. |
| `user_turns` | integer | sim | Turnos do usuário. |
| `assistant_turns` | integer | sim | Turnos do assistente. |
| `tool_calls` | integer | sim | Chamadas de ferramenta. |
| `files_changed` | jsonb | sim | Arquivos alterados reportados pela origem. |
| `personal` | boolean | sim | Se true, não participa da triagem de trabalho nem cálculo de tempo. |
| `user_id` | bigint | não | Usuário associado, quando houver. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: `thread_id` único; índice por `workspace_hash`, `last_ts`, `user_id`; FK para `users` com nullify.

### 3.2. `conversation_turn_refs`

Índice de offsets para lazy-load dos turnos. Armazena ponteiros, não o texto integral da conversa.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `conversation_id` | uuid | sim | Conversa relacionada. |
| `turn_source_id` | uuid | sim | Arquivo/fonte indexado. |
| `thread_id` | text | sim | Thread da linha indexada. |
| `line_no` | integer | sim | Linha no arquivo normalizado. |
| `byte_offset` | bigint | sim | Offset para leitura direta. |
| `role` | text | não | Papel do turno. |
| `ts` | timestamptz | não | Timestamp do turno. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FKs para `conversations` e `turn_sources` com cascade; unicidade por fonte+linha; CHECK de linha positiva e offset não negativo.

### 3.3. `turn_sources`

Arquivos normalizados indexados para lazy-load.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `source_file` | text | sim | Caminho do arquivo normalizado. |
| `source_label` | text | sim | Rótulo da origem. |
| `source_mtime` | timestamptz | sim | Mtime do arquivo. |
| `size_bytes` | bigint | sim | Tamanho. |
| `content_hash` | text | sim | Hash de conteúdo. |
| `schema_version` | text | sim | Versão do schema do arquivo. |
| `status` | text | sim | `pending`, `ok`, `partial`, `stale` ou `error`. |
| `indexed_at` | timestamptz | não | Momento de indexação. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: fingerprint único por arquivo/tamanho/mtime/hash/schema.

### 3.4. `workspace_maps`

Mapeamento entre hash de workspace e pasta legível.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `workspace_hash` | text | sim | Hash do workspace. |
| `folder` | text | não | Caminho resolvido. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: `workspace_hash` único.

### 3.5. `conversation_links`

Vínculo entre conversa e tarefa.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `conversation_id` | uuid | sim | Conversa vinculada. |
| `task_id` | uuid | sim | Tarefa vinculada. |
| `link_type` | text | sim | `primary` ou `mention`. |
| `origin` | text | sim | `manual`, `auto` ou `suggestion`. |
| `confidence` | decimal | não | Confiança da sugestão, entre 0 e 1. |
| `created_by_id` | bigint | não | Usuário criador. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FKs para conversa e tarefa com cascade; no máximo um `primary` por conversa; tripla conversa+tarefa+tipo única.

### 3.6. `conversation_triages`

Decisão persistida de triagem da conversa.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `conversation_id` | uuid | sim | Conversa triada. |
| `status` | text | sim | `open`, `reviewed` ou `ignored`. |
| `confirmed_client_id` | uuid | não | Cliente confirmado manualmente. |
| `confirmed_project_id` | uuid | não | Projeto confirmado manualmente. |
| `note` | text | não | Observação da triagem. |
| `triaged_by_id` | bigint | não | Usuário responsável. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: uma triagem por conversa; conversa cascade; cliente/projeto/usuário nullify.

### 3.7. `conversation_activity_drafts`

Rascunhos de atividades sugeridas/manualizadas na triagem.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `conversation_id` | uuid | sim | Conversa dona do rascunho. |
| `title` | text | sim | Título da atividade. |
| `description` | text | não | Descrição. |
| `status` | text | sim | `draft`, `confirmed` ou `discarded`. |
| `source` | text | sim | `manual` ou `ia_local`. |
| `position` | integer | sim | Ordenação. |
| `created_by_id` / `updated_by_id` | bigint | não | Usuários de auditoria. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: conversa cascade; usuários nullify; CHECKs de status e fonte.

### 3.8. `conversation_work_blocks`

Blocos de trabalho da triagem. São rascunhos/validações de tempo, não apontamentos oficiais.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `conversation_id` | uuid | sim | Conversa dona do bloco. |
| `client_id` / `project_id` / `task_id` | uuid | não | Classificação operacional do bloco. |
| `period_date` | date | sim | Data do bloco. |
| `day_period` | text | sim | `manha`, `tarde` ou `noite`; classificatório/visual. |
| `start_time` / `end_time` | timestamptz | não | Janela sugerida/editável. |
| `duration_seconds` | integer | sim | Duração validada em segundos. |
| `kind` | text | sim | `execution` ou `gap`. |
| `gap_kind` | text | não | Tipo de gap quando `kind=gap`. |
| `status` | text | sim | `draft`, `confirmed` ou `discarded`. |
| `source` | text | sim | `manual` ou `ia_local`. |
| `summary` | text | não | Resumo textual. |
| `notes` | text | não | Notas de validação. |
| `needs_external_evidence` | boolean | sim | Indica evidência fora da conversa. |
| `external_evidence_note` | text | não | Descrição da evidência externa. |
| `position` | integer | sim | Ordenação. |
| `created_by_id` / `updated_by_id` | bigint | não | Usuários de auditoria. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: conversa cascade; cliente/projeto/tarefa nullify; usuários nullify; CHECKs de período, tipo, status, fonte, gap e duração.

## 4. Tabelas de sincronização

### 4.1. `sync_executions`

Execução de sync/coleta/importação vista pela aplicação.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `status` | string | sim | `queued`, `running` ou estados finais definidos pela aplicação. |
| `trigger` | string | sim | Origem da execução; default `manual`. |
| `requested_by_id` | bigint | não | Usuário solicitante. |
| `current_step` | string | não | Etapa corrente. |
| `started_at` / `finished_at` | datetime | não | Janela da execução. |
| `pipeline_exit_code` | integer | não | Exit code do pipeline nativo. |
| `pipeline_summary` | text | não | Resumo da execução do pipeline. |
| `error_message` | text | não | Erro agregado. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: índice único parcial impede mais de uma execução ativa.

### 4.2. `sync_runs`

Resultado de importação de um arquivo/fonte normalizada.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `sync_execution_id` | uuid | não | Execução agregadora. |
| `source_file` / `source_label` | text | não | Arquivo/fonte importada. |
| `schema_version` | text | não | Versão do schema normalizado. |
| `source_mtime` | timestamptz | não | Mtime da fonte. |
| `started_at` / `finished_at` | timestamptz | não | Janela da importação. |
| `status` | text | sim | `ok`, `partial` ou `error`. |
| `lines_processed` | integer | sim | Linhas lidas. |
| `imported` | integer | sim | Conversas importadas. |
| `updated` | integer | sim | Conversas atualizadas. |
| `skipped` | integer | sim | Linhas ignoradas. |
| `error_lines` | integer | sim | Linhas com erro. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK opcional para `sync_executions`; CHECKs de contadores não negativos e status.

### 4.3. `sync_run_items`

Itens de auditoria de um sync run.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `sync_run_id` | uuid | sim | Run dono do item. |
| `status` | text | não | `error` ou `skipped`. |
| `reason` | text | não | Motivo do erro/skip. |
| `thread_id` | text | não | Thread relacionada. |
| `line_number` | integer | não | Linha relacionada. |
| `raw_excerpt` | text | não | Trecho bruto para auditoria. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: FK para `sync_runs` com cascade.

### 4.4. `sync_schedules`

Configuração singleton do agendamento de sync.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `enabled` | boolean | sim | Liga/desliga agendamento. |
| `interval_minutes` | integer | sim | Intervalo configurado. |
| `last_enqueued_at` | datetime | não | Último enfileiramento. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: índice único em `(true)` garante singleton.

## 5. Tabelas auxiliares

### 5.1. `configurable_statuses`

Status configuráveis de tarefas e projetos.

| Campo | Tipo | Obrigatório | Descrição |
|---|---:|---:|---|
| `id` | uuid | sim | Chave primária. |
| `entity_type` | string | sim | `task` ou `project`. |
| `key` | string | sim | Chave persistida em `tasks.status` ou `projects.status`. |
| `name` | string | sim | Rótulo exibido. |
| `color` | string | sim | Cor/badge. |
| `position` | integer | sim | Ordenação. |
| `active` | boolean | sim | Disponível para novos registros. |
| `final` | boolean | sim | Indicador visual de status final. |
| `created_at` / `updated_at` | datetime | sim | Auditoria técnica. |

Chaves e índices: `entity_type,key` único; usado por FK composta em `tasks` e `projects`.

### 5.2. Solid Queue

Tabelas internas do Rails/Solid Queue:

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

Essas tabelas são infraestrutura de fila. Não representam domínio de negócio. Limpezas nelas devem seguir runbook de operação, não scripts ad hoc durante correção de dados de conversa.

## 6. Regras específicas para a reconstrução pós-incidente de telemetria

1. Fazer `pg_dump` antes de qualquer alteração.
2. Confirmar `SyncSchedule.enabled=false`.
3. Rodar `sync:integrity_report` em modo read-only.
4. Reparar/importar apenas pelo fluxo corrigido que ignora fontes não conversacionais.
5. Remover somente conversas fantasmas sem vínculo humano confirmado.
6. Nunca remover `tasks`, `demands`, `time_entries`, `clients`, `projects`, `contracts`, `conversation_links`, `conversation_triages`, `conversation_activity_drafts` ou `conversation_work_blocks` por atalho.
7. Rebuild de `conversation_turn_refs` deve ocorrer somente após estabilizar `conversations`.
8. Religar `SyncSchedule` somente após validação de contagens e smoke da Triagem.
