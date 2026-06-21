# Omni — Diário de Entregas

> Append-only. Entradas mais recentes no topo. **Não registrar entrega sem evidência objetiva.**

## Como usar
- Criar uma nova entrada a cada entrega real (merge/validação), nunca a cada commit.
- Sempre anexar evidência objetiva (contagem, saída de teste, critério comprovado).
- Atualizar `PROJECT_STATUS.md` e `FEATURE_MATRIX.md` na mesma sessão da entrada.

## Entradas

## 2026-06-21 — [Produto Operacional · PB-006] Clientes e contatos operacionais + busca de CNPJ — ENTREGUE
### Resumo
`/clients` utilizável no dia a dia (abas Empresas/Contatos) + cadastro via busca de CNPJ. **Aceite do PO.** Migration aditiva. Decisão de produto: a busca de CNPJ — antes fora de escopo na PB-006 — foi **incluída** pelo PO, via **proxy no Rails** (ver **ADR-022**).
### Entregue
- **Abas server-side** (`tab=companies|contacts`, default companies).
- **Empresas:** busca por nome/razão social, nome fantasia e **CNPJ com OU sem pontuação** (`%`/`_` escapados; sem chamada externa na busca); filtro status; paginação 10/25/50/100 (default 50; ordem `name asc, id asc`; params preservados; página inválida → 1); colunas nome/fantasia/CNPJ(formatado)/telefone/status/**contato principal**/ações (ver/editar/excluir + confirmação); "Novo cliente" destacado.
- **Contatos:** busca por nome/e-mail/telefone/cargo; filtros cliente / status do cliente / principal (todos/sim/não); mesma paginação; ações editar/excluir + link p/ cliente.
- **Contato principal:** **índice único parcial** `contacts(client_id) WHERE is_primary` (ETAPA ZERO confirmou 0 clientes com >1 principal) + regra **transacional** no model (salvar principal desmarca o anterior do mesmo cliente; isola outros clientes; concorrência barrada pelo índice; excluir o principal pode deixar sem principal).
- **Cadastro via busca de CNPJ (proxy no Rails — ADR-022):** `GET /clients/cnpj_lookup` (Pundit) → `Cnpj::Lookup` consulta a **BrasilAPI no servidor** com **host fixo allowlist + timeout 5s + falha graciosa**, sem persistir resposta crua; mapeia razão social/nome fantasia/telefone/endereço. Autopreenchimento no form via Stimulus = **melhoria progressiva** (sem JS, cadastro segue manual). O usuário fornece só os 14 dígitos; URL/host nunca vêm do usuário.
- **Integridade:** `policy_scope` (Client e Contact); `includes` sem N+1; filtros no banco; total antes de limit/offset; estados vazios + "Limpar filtros".
### Validação
Suíte **459 runs / 1813 assertions / 0** falhas/erros/skips; rubocop **163/0**; brakeman **0**; `git diff --check` limpo. Testes novos cobrem busca (nome/fantasia/CNPJ-fmt/`%`/`_`), filtros, paginação/inválidos, contato principal (substituição/isolamento/constraint concorrente), proxy de CNPJ (stub de rede; 422/404/timeout/host fixo), endpoint (auth/JSON), ações, vazios, N+1. Validação visual do PO: OK. Banco dev sem massa artificial.
### Decisão / nota
- **ADR-022** registra a fronteira de saída externa (proxy de CNPJ): allowlist + timeout + sem input do usuário + sem persistir resposta crua. Mesma filosofia do ADR-011, porém para chamada HTTP de saída.
### Fora de escopo (cumprido)
Sem Projetos (WD-03)/PB-007; sem PB-013/014/016; sem persistir/cachear a resposta crua do CNPJ; sem chamadas externas em outras telas; `_origem/`/`_mockup/` intocados.

## 2026-06-21 — [Produto Operacional · PB-005] Lista operacional de demandas — ENTREGUE (+ PB-004 concluída)
### Resumo
`/demands` utilizável no dia a dia (busca, filtros, paginação, ações, conversão pela lista). **Aceite do PO.** Registra também a **conclusão da PB-004** (a/b/c). Sem migration/schema/dependência; reutiliza `ConvertDemand` + vínculo 1:1 (PB-004c).
### Entregue
- **Busca** (`q`) por **título / descrição / observações** — `ILIKE` case-insensitive; `%` e `_` escapados (texto, não curinga).
- **Filtros combináveis** prioridade/origem/status/cliente (allowlist; inválidos ignorados).
- **Paginação** `page`/`per_page` (10/25/50/100, default 50; total antes de limit/offset; ordem estável `created_at desc, id desc`; links preservam params; página inválida → 1).
- **Tabela:** Demanda (título+trecho), Cliente, Origem, Prioridade, Status, Criada em, Ações.
- **Conversão por estado (PB-004c):** pending+cliente → **Converter** (confirmação); pending **sem cliente** → "sem cliente" (não convertível); **converted** → "Abrir tarefa" (sem nova conversão). + Ver/Editar/Excluir (confirmação); "Nova demanda" destacada.
- **Estados vazios:** nenhuma cadastrada / nenhum resultado (+ "Limpar filtros").
- **Integridade:** `policy_scope`; `includes(:client, :converted_task)` **sem N+1** (carrega página 1×); filtros no banco.
### Validação
Suíte **426 runs / 1691 assertions / 0** falhas/erros/skips; rubocop **157/0**; brakeman **0**; `git diff --check` limpo. 25 testes novos (busca título/descrição/observações/case/`%`/`_`; filtros; combinações; inválidos; paginação/per_page/página-inválida; links preservam params; conversão pela lista; pending sem cliente; converted→link; 2ª conversão bloqueada; ações; vazios; auth; N+1). Validação visual do PO: OK. Banco dev sem massa artificial.
### Decisão / pendências
- **PB-004 concluída** (a/b/c) — sem PB-004d genérica (decisão do PO).
- **Busca global da topbar** ("Buscar… (em breve)") permanece placeholder; decisão/implementação → **PB-013** (afeta layout global).
### Fora de escopo (cumprido)
Sem cards complexos (tabela resolveu); sem Projetos/Clientes (PB-006); sem PB-013/014/016; sem migration/dependência; sem alterar schema/models de vínculo/regras de exclusão; `_origem/`/`_mockup/` intocados.

## 2026-06-21 — [Produto Operacional · PB-004c] Vínculo demanda↔tarefa — ENTREGUE
### Resumo
Fatia **c** da PB-004: persistir e exibir a demanda que originou uma tarefa (relação opcional 1:1) com ciclo de exclusão coerente. **Aceite do PO.** Migration **aditiva**; não toca PB-003/checklist/conversas.
### Entregue
- **Schema:** `tasks.demand_id` uuid null + FK `demands` **ON DELETE RESTRICT** + **índice único parcial** (`WHERE demand_id IS NOT NULL`) → ≤1 tarefa por demanda; ≤1 demanda por tarefa.
- **Associações:** `Task belongs_to :origin_demand` (opcional); `Demand has_one :converted_task` (`dependent: :restrict_with_error`); validação de unicidade no model + barreira no banco.
- **Conversão (`ConvertDemand`):** transação única, **lock pessimista + revalidação pós-lock**, cria a tarefa **já vinculada** (`demand_id`), marca `converted`/`converted_at`; 2ª conversão falha sem criar tarefa; concorrência não gera 2ª tarefa.
- **Exclusão da tarefa (`DeleteTask`, serviço explícito — sem callback oculto):** transação + lock (task+demand); se originada por demanda, devolve-a a **pending** e limpa `converted_at` antes de excluir a tarefa; rollback integral em falha; tarefa sem demanda exclui normal. `TasksController#destroy` usa o serviço (mensagem clara).
- **Exclusão da demanda:** vinculada → **bloqueio amigável** na app + FK RESTRICT como proteção final; pending sem vínculo continua excluível.
- **UI:** aba **Demanda** funcional na tarefa (título/descrição/origem/prioridade/status/convertida em/abrir; estado vazio honesto) — virou link de âncora real; na demanda convertida, **link p/ a tarefa** e **sem** oferecer nova conversão.
- **Reconciliação do banco dev (transacional, fora da migration):** validadas 9 condições e aplicado o vínculo histórico **Demand `4549551a…` ↔ Task `8bcbbcb5…`** (título/descrição/cliente idênticos, type=support, status=pending, sem outra tarefa apontando); associação bidirecional confirmada; as 2 demandas pending **intactas**.
### Validação
Suíte **401 runs / 1601 assertions / 0** falhas/erros/skips; rubocop **156/0**; brakeman **0**; `git diff --check` limpo. 22 testes novos (conversão cria vínculo + bidirecional; unicidade model/banco; conversão repetida; concorrência; exclusão da tarefa devolve demanda a pending + converted_at limpo; rollback; tarefa sem demanda; demanda vinculada não-excluível; demanda livre excluível; UI tarefa/demanda; auth; regressão checklist/conversas/PB-003). Validação visual do PO: OK.
### Pendências
- **PB-004d+:** demais melhorias do detalhe `/tasks/:id`, conforme priorização do PO.
### Fora de escopo (cumprido)
Sem várias tarefas por demanda; sem progresso agregado/outras tarefas da demanda; sem histórico auditável/atividade recente; sem alterar PB-003/checklist; sem PB-005/006/013/014/016; `_origem/`/`_mockup/` intocados.

## 2026-06-21 — [Produto Operacional · PB-004b] Checklist persistente da tarefa — ENTREGUE
### Resumo
Fatia **b** da PB-004: checklist persistente na seção Detalhes de `/tasks/:id`. **Aceite do PO.** Migration **aditiva** (não altera/remove dados existentes); não toca PB-003/PB-005/006/013/014/016.
### Entregue
- **Model `ChecklistItem`:** uuid; `task_id` FK **ON DELETE CASCADE**; `content` text (trim via `normalizes` + presence); `completed` boolean NOT NULL default false; ordem explícita `created_at, id` (scope `ordered`; **sem** `position`/`default_scope`). `Task has_many :checklist_items, dependent: :delete_all`.
- **Rotas aninhadas** em `tasks` (create/update/destroy) + **`ChecklistItemPolicy`** (ADR-014). Itens **sempre escopados pela tarefa da URL** (cruzar IDs → 404). Strong params só **`content`/`completed`** (`task_id` vem da URL).
- **UI** na seção Detalhes: contador concluído/total, estado vazio, **adicionar** (form sempre visível), **marcar/desmarcar** (☐/☑), **editar in-place** (a linha alterna exibição↔edição via `<details>` nativo, **sem JS**; Salvar/Cancelar; altura estável), **excluir** com confirmação. Item concluído tachado/esmaecido.
### Validação
Suíte **379 runs / 1503 assertions / 0** falhas/erros/skips; rubocop **152/0**; brakeman **0**; `git diff --check` limpo. 24 testes novos (criação/trim/vazio/edição/marcar-desmarcar/exclusão/ordem/cascade/isolamento entre tarefas/auth/params não permitidos/estado vazio+contador/edição in-place + regressão da página da tarefa e PB-003). Validação visual do PO: OK. Banco dev sem massa artificial.
### Pendências
- **PB-004c+:** vínculo demanda↔tarefa; demais melhorias do detalhe `/tasks/:id`.
### Fora de escopo (cumprido)
Sem drag-and-drop/reordenação/subtarefas/prazo/responsável/prioridade por item; sem histórico auditável; sem vínculo demanda↔tarefa; sem alterar PB-003; sem PB-005/006/013/014/016; `_origem/`/`_mockup/` intocados.

## 2026-06-21 — [Produto Operacional · PB-004a] Lista operacional de /tasks — ENTREGUE
### Resumo
Fatia **a** da PB-004: `/tasks` utilizável no dia a dia (busca, filtros, paginação, ações). **Aceite do PO.** Sem migration/schema/dependência; sem alterar regras de criação/edição/exclusão da tarefa.
### Entregue
- **Busca** (`q`) por **título ou descrição** — `ILIKE` case-insensitive; `%` e `_` **escapados** (tratados como texto, não curingas).
- **Filtros combináveis** `status`/`type`/`client_id` (allowlist; valores inválidos **ignorados** sem quebrar).
- **Paginação** `page`/`per_page` (10/25/50/100, default **50**); **total antes de limit/offset**; ordenação **estável** `created_at desc, id desc`; "N tarefa(s) · página X/Y"; Anterior/Próxima **preservam** busca+filtros+per_page; página inválida/negativa → 1.
- **Tabela:** Tarefa (título + trecho da descrição), Cliente, Projeto, Status, Tipo, Criada em, Ações.
- **Ações** ver/editar/excluir (ícones Omni; **confirmação** ao excluir); "Nova tarefa" destacada.
- **Estados vazios:** nenhuma cadastrada (+ Nova tarefa) / nenhum resultado (+ **Limpar filtros**).
- **Integridade:** `policy_scope` preservado; `includes(:client, :project)` **sem N+1** (carrega página 1×); filtros no banco.
### Validação
Suíte **355 runs / 1432 assertions / 0** falhas/erros/skips; rubocop **146/0**; brakeman **0**; `git diff --check` limpo. 23 testes novos (busca/`%`/`_`/filtros/combinações/inválidos/paginação/links/ações/vazios/auth/N+1). Validação visual do PO: OK. Banco dev intocado (sem massa artificial).
### Pendências
- **PB-004b+:** checklist persistente; vínculo demanda↔tarefa; melhorias do detalhe `/tasks/:id`.
### Fora de escopo (cumprido)
Sem checklist/demanda↔tarefa/detalhe; sem código legível (PB-014); sem PB-005/006/016; sem migration/dependência; `_origem/`/`_mockup/` intocados.

## 2026-06-21 — [Produto Operacional · PB-015] Sincronização operacional de conversas — ENTREGUE (MVP)
### Resumo
Importação operacional de conversas pela UI, **sem o usuário depender de comandos Rails** e **sem o Rails executar o pipeline** (ADR-011). **Aceite manual do PO + validação ponta a ponta.** Migration aditiva; pipeline externo intocado.
### Entregue
- **UI `/sync_runs` operacional:** botão **"Atualizar conversas no Omni"** enfileira `SyncConversationsJob` (CSRF/Pundit); **botão desabilitado**, **barra de progresso por etapa** e **auto-refresh** durante execução ativa; status/contadores/erro seguro da última execução; bloqueio de nova solicitação com execução ativa.
- **`Sync::RunConversationsSync`:** lê **apenas** `config.x.normalized_dir` (allowlist, default `/normalized` `:ro`; nunca path do usuário); ordem **ImportSummaries → BuildConversationTurnRefs**; **advisory lock** (Postgres) anti-concorrência; **settle/verify** de fingerprint antes/depois (aborta e **preserva o índice anterior** se o arquivo mudar durante a leitura). `ResolveWorkspaceFolders` fora do MVP (workspaceStorage não montado).
- **Status agregado `SyncExecution`** (orquestra os `SyncRun` por etapa, sem confundir com o run individual); índice único parcial de 1 execução ativa.
- **Correção técnica:** falso no-op do fingerprint de `turn_refs` — `source_mtime` na chave do `find_by` + hash de **cabeça+miolo+cauda**.
- **Worker `omni_jobs`** isolado no devstack (`.devstack/jobs.sh`; sem `SOLID_QUEUE_IN_PUMA`), `/normalized` `:ro` no web e no worker.
- **Orquestração externa** `app/script/SyncOmniConversations_PB015_v1.ps1`: roda o pipeline e enfileira a importação (mutex global, exit codes, sem logar segredos/conteúdo). **O Rails não executa Python.**
- **Preservação:** upsert por `thread_id`; **nunca deleta** conversas ausentes; `tasks` e `conversation_links` intactos.
### Validação
Suíte **332 runs / 1350 assertions / 0** falhas/erros/skips; rubocop **145/0**; brakeman **0**; `git diff --check` limpo; PowerShell validado por parser (não executado nos testes). **Ponta a ponta (2026-06-21):** o script rodou o **pipeline real** (regenerou `output/normalized`) e a importação trouxe **12 conversas novas** → **conversations 1635 → 1647**, **turn_refs → 134653**; `conversation_links` e `tasks` preservados; status agregado **partial** (skips esperados de linhas sem thread/conversa). Validação visual do PO: OK.
### Pendências / direção
- **PB-016 — agendador interno de importação** (Configurações; intervalos; processo da app; sem Tarefa do Windows; disparo do pipeline sob allowlist/timeout) — **proposto** (addendum ao ADR-011).
- **PB-004 liberada para retomada** (dependência operacional destravada).
### Fora de escopo (cumprido)
Rails não dispara o pipeline; sem agendamento automático; sem timesheet/relatórios; `_origem/` intocado.

## 2026-06-20 — [Produto Operacional · PB-003c] Apontamento retroativo assistido + timers globais — ENTREGUE (`0f2bc9c`)
### Resumo
Fatia **c** (final) da PB-003. **Aceite manual do PO concluído.** Com PB-003a + PB-003b + PB-003c, a **PB-003 — Controle de tempo operacional — está INTEGRALMENTE CONCLUÍDA** (entregue, aceita e publicada). Apresentação + regras de model; **sem schema/migração/dependência**.
### Entregue
- **Registro retroativo assistido:** formulário por **início + término** (defaults: tarefa pré-selecionada quando vem de `/tasks/:id`, início = agora sem segundos, término em branco); labels "Início (data e hora)" / "Término (data e hora)"; títulos/links "Novo apontamento retroativo".
- **Duração derivada no model:** `duration = término − início` em **segundos**; `date` **sempre** derivada de `start_time.to_date`. Campos `duration`/`date`/`is_running` removidos do formulário e dos strong params; `conversation_id` segue não atribuível. `end_time` **obrigatório** para apontamento não running; `end_time ≥ start_time` (erro claro, sem mascarar).
- **Proteção do timer running:** running deve ter `end_time` nil e `duration = 0` (validações); CRUD genérico em running só altera **descrição** (tarefa/início/término/data/duração intactos); timers seguem geridos exclusivamente por `start_for`/`stop!`.
- **Aviso global de timers:** banner na topbar "N timer(s) em andamento" (renderiza só com N>0; **1 query COUNT** memoizada) com link para a lista.
- **Lista global de timers** `/time_entries/running`: tarefa, cliente, início, tempo decorrido estático, **Abrir tarefa** e **Parar**; autenticada/autorizada; `policy_scope.running.includes(task: :client)`; **sem N+1**.
- **Nota de sobreposição** (Histórico e lista): "Os totais representam tempo lançado. Com apontamentos ou timers paralelos, podem exceder o tempo cronológico."
- **Ajuste visual final do histórico:** cabeçalho de data com padding alinhado à 1ª coluna; subtotal diário alinhado por padding (sem margin); **total geral movido para `<tfoot>`** dentro da tabela (rótulo nas 3 primeiras colunas, valor na coluna Duração, alinhado aos subtotais), classe `.te-total` preservada.
### Validação
`bin/rails test` **308 runs / 1246 assertions / 0** falhas/erros/skips; rubocop **135/0**; brakeman **0**; `git diff --check` limpo. Cobertura nova: defaults do new; create retroativo calcula duração em segundos; date derivada; end_time obrigatório p/ não running; término anterior bloqueado; duration/date/is_running ignorados via params; conversation_id bloqueado; edição retroativa recalcula; edição de running não altera campos temporais/tarefa; running exige end_time nil + duration 0; aviso global presente/ausente; lista só running + tarefa/cliente/ações; anônimo redirecionado; sem N+1; sobreposição soma normalmente; nota presente; estrutura visual (cabeçalho/subtotais/`tfoot`); regressões PB-003a/PB-003b verdes. **Aceite manual do PO concluído.**
### PB-003 — conclusão
**PB-003 integralmente entregue** (a/b/c entregues, aceitas e publicadas). 16 caminhos no commit `0f2bc9c` (14 modificados + 2 novos: `app/views/shared/_running_timers_banner.html.erb`, `app/views/time_entries/running.html.erb`).
### Fora de escopo (cumprido)
Sem migration/schema/dependência; sem timesheet/relatórios/faturamento (futuro, fora da PB-003); sem PB-013/PB-014/F7.2; sem alterar ROADMAP/`PB-003_TIME_CONTRACT`; `_origem/`/`_mockup/` intocados.

## 2026-06-20 — [Produto Operacional · PB-003b] Histórico de apontamentos: agrupamento e subtotal por dia — ENTREGUE (`5fcf125`)
### Resumo
Fatia **b** da PB-003: o "Histórico de Apontamentos" (`/tasks/:id`) passa a **agrupar por data**, com **subtotal diário**. **Aceite manual do PO.** Apresentação apenas (sem schema/migração); PB-003c (retroativo assistido) **pendente** — PB-003 segue **parcialmente entregue**.
### Entregue
- **Agrupamento por data:** um `tbody.te-day` por dia; **grupos em ordem decrescente** (mais recente primeiro); **itens por horário decrescente** dentro do dia; data em **PT-BR** no cabeçalho do grupo.
- **Subtotal diário** (via `duration_label`, em segundos) **excluindo timers em andamento** (`reject(&:is_running)`); **total geral** e **ações inline** (ver/editar/excluir/parar) preservados; timer em andamento permanece visível no grupo da sua data.
- **Sem N+1:** entradas carregadas 1× (`.to_a`) e agrupadas em memória; `running` derivado da coleção (eliminou 1 query).
- Arquivos: `app/views/tasks/show.html.erb`, `app/assets/stylesheets/application.css`, `test/integration/tasks_test.rb`.
### Validação
`bin/rails test` **295 runs / 1181 assertions / 0** falhas; rubocop **135/0**; brakeman **0**. Teste reforçado valida cada grupo isoladamente (data correta + subtotal só daquele dia), ordem intradiária decrescente e timer no grupo correto/fora do subtotal. **Aceite manual do PO** no fluxo.
### Pendências
- **PB-003c:** registro retroativo assistido.
- (roadmap) PB-013 UX de navegação; PB-014 código legível de tarefa.
### Fora de escopo (cumprido)
Sem PB-003c/retroativo; sem migration/schema; sem alterar start/stop/paralelismo (`ALLOW_PARALLEL_RUNNING_TIMERS`); sem `conversation_id`; sem dashboard/relatórios; `_origem/`/`_mockup/` intocados.

## 2026-06-19 — [Produto Operacional · PB-003a] Controle de tempo: timer + histórico de apontamentos — ENTREGUE (`d11f099`)
### Resumo
Núcleo do controle de tempo operacional na tarefa (fatia **a** da PB-003). **Aceite manual do PO** no fluxo principal. **PB-003b/PB-003c permanecem pendentes** — PB-003 não está concluída.
### Entregue
- **Timer:** iniciar (`TaskTimersController#create` → `/tasks/:id/timer`) e parar (`TimeEntriesController#stop` → `/time_entries/:id/stop`); `TimeEntry#stop!` calcula **`duration` em segundos**.
- **Paralelismo configurável:** `ALLOW_PARALLEL_RUNNING_TIMERS` (ENV via `config.x`, **default `true`**) — permite timers abertos em tarefas diferentes; `false` bloqueia novo timer havendo qualquer aberto.
- **Invariante de banco:** **índice único parcial** `idx_time_entries_one_running_per_task` (`WHERE is_running`) + validação → nunca 2 timers abertos na **mesma** tarefa.
- **Histórico de Apontamentos** (`/tasks/:id`): título PT + contador; colunas Data/Descrição/Início/Término/Duração/Ações; duração destacada (segundos→h/min/s via `duration_label`); **ações inline** ver/editar/excluir + parar (ícones estilo lucide autorados, cores por ação verde/azul/vermelho, `aria-label`/`title`, confirmação de exclusão, fallback HTML).
### Validação
`bin/rails test` **294 runs / 1151 assertions / 0** falhas; rubocop **135/0**; brakeman **0**. **Aceite manual do PO:** iniciar/parar timer, paralelismo entre tarefas (default), histórico operacional e ações na linha — OK. Modo `ALLOW_PARALLEL_RUNNING_TIMERS=false` **coberto por teste automatizado** (não necessariamente por aceite manual).
### Pendências explícitas
- **PB-003b:** agrupamento por data + **subtotal por dia** + melhoria do total diário.
- **PB-003c:** registro retroativo assistido.
- **PB-013:** UX de navegação/contexto entre telas (observação do PO).
- **PB-014:** código legível de tarefa (ADR-016 — decisão do PO).
### Fora de escopo (cumprido)
Sem PB-003b/PB-003c; sem vínculo `conversation_id`; sem dashboard/relatórios; sem alterar `_origem/`/`_mockup/`. ENV-only (sem tela de config). Migration aplicada (gate respeitado: commitada sob autorização).

## 2026-06-19 — [Fase 7 · F7.1] Endurecimento de produção + admin seed — CONCLUÍDO
### Resumo
Primeira fatia de readiness de produção: `production.rb` endurecido **por ENV** e **admin seed** opt-in/idempotente. **Sem** schema/migration/Solid/Kamal/Dockerfile/credentials/deploy. Gate separado (auth/seed): implementado e validado; commit sob autorização.
### Entregue
- **`config/environments/production.rb`** (ENV; sem domínio/segredo hardcoded): `config.assume_ssl`←`APP_ASSUME_SSL` (default true), `config.force_ssl`←`APP_FORCE_SSL` (default true), `ssl_options` exclui `/up`; `config.hosts += APP_HOSTS` (lista por vírgula, só não-vazios após `strip`; sem `APP_HOSTS` não restringe); mailer `default_url_options` por `APP_HOST`/`APP_PROTOCOL`. Parser booleano via `ActiveModel::Type::Boolean`.
- **`db/seeds.rb`** — admin OPT-IN (`OMNI_SEED_ADMIN`) + `OMNI_ADMIN_EMAIL`/`OMNI_ADMIN_PASSWORD`/`OMNI_ADMIN_USERNAME`: sem flag → no-op (CI verde); flag sem e-mail/senha → raise claro; idempotente (busca por e-mail; cria `role:"admin"`; existente não duplica/não troca senha, só promove); senha nunca logada. **Sem alterar `User`/policies.**
- **`test/seeds_admin_test.rb`** (5 testes): no-op; raise; cria admin; idempotência; promoção sem trocar senha.
- **`docs/F7_CONTRACT_DECISIONS.md`** (novo) — fronteira F7 + decisões/ENV da F7.1.
### Testes/validações
`bin/rails test` **279 runs / 1087 assertions / 0** falhas; rubocop **133/0**; brakeman **0**; bundler-audit **0**. `RAILS_ENV=test bin/rails db:seed:replant` → no-op (users=0). Smoke de config (`SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails runner`, sem servidor/segredo): defaults → `force_ssl/assume_ssl=true`, `hosts=[]`, mailer `localhost/https`; com ENV → flags `false`, `hosts=[omni.example.com, www.omni.example.com]`, mailer `omni.example.com`.
### Fora de escopo (cumprido)
Sem schema/migration, Solid cache/cable/queue, Kamal, Dockerfile, credentials/secrets, deploy; sem seed real em dev/prod; `_origem/`/`_mockup/` intocados.

## 2026-06-19 — [Fase 5 · Fechamento] F5 declarada MVP interno CONCLUÍDO — (docs-only)
### Resumo
Fechamento **somente documental** da Fase 5 como **MVP interno utilizável**, após avaliação read-only (7 smokes verdes). Sem alterar código/testes/banco/assets. Supersede o snapshot "F5/M5 → 🟡 ABERTA" da entrada P0 (2026-06-18), preservada como histórico.
### Fluxo interno essencial (completo e validado)
listar conversas → filtrar por vínculo (`none`/`primary`/`mention`) → abrir conversa → renderizar turnos com segurança → **redigir PII** → **markdown sanitizado** → criar tarefa a partir da conversa → vincular conversa↔tarefa → ver o vínculo dos dois lados → navegar a task por âncoras.
### Sub-entregas da F5
F5.1 (render read-only) · F5.1.1–F5.1.4 (correções + `source_file` oculto + runtime + limpeza dev) · F5.1.5 (PII) · F5.2 (markdown sanitizado) · F5.3 (criar tarefa — UI-10) · F5.4 (lista acionável — CV-04) · F5.5 (navegação por âncoras — UI-03).
### Reclassificado para roadmap/v1 (NÃO entregue)
UI-01 dashboard · UI-04 aba Conversas rica/por kind · UI-09 modal Ctrl+L · CV-03 títulos (limitado pelo dado) · CV-10 tags · CV-05 melhorias (syntax highlight, busca, virtualização) · CV-06 ordenação por `seq` · abas dinâmicas JS (opcional) · scorer/sugestões/auto-link (LK-04/05/06) · inbox/triagem avançada (UI-05) · arquivos alterados (CV-09).
### Métricas (estado atual)
`bin/rails test` **274 runs / 1068 assertions / 0** falhas; rubocop **132/0**; brakeman **0**; bundler-audit **0**.
### Arquivos
`docs/PROJECT_STATUS.md`, `docs/FEATURE_MATRIX.md`, `docs/ROADMAP.md`, `docs/F5_CONTRACT_DECISIONS.md`, `docs/DELIVERY_LOG.md`.

## 2026-06-19 — [Fase 5 · F5.5] Usabilidade da Task: navegação por âncoras/seções — CONCLUÍDO
### Resumo
As "abas" cosméticas de `tasks/show` (`span.tab`, `cursor:default`, sem troca) viram **navegação honesta por âncoras (sem JS)**: os itens reais são `<a class="tab" href="#tab-…">` que rolam até a seção (painéis seguem visíveis/empilhados). Resolve a afordância falsa que confundia no pós-vínculo (F5.3).
### Entregue
- **Itens reais → links de âncora:** Detalhes (`#tab-detalhes`), Conversas (`#tab-conversas`), Time entries (`#tab-time`).
- **"Conversas (N)"**: contagem exibida quando há conversas vinculadas (destaca o vínculo recém-criado); ausente quando 0.
- **"Histórico"/"Demanda"**: permanecem `span.tab.soon` **sem `href`** (`aria-disabled`) — não parecem ação.
- **CSS escopado** (só `.tab*`, usado apenas na task): `a.tab` com cursor/hover de link; `scroll-margin-top` nas seções; realce `:target` (CSS puro); `.tab.soon { cursor: default }`.
- Painel `#tab-conversas` mantém a lista de conversas vinculadas com "Ver" → conversa.
### Sem JS / sem dinâmica
Nenhum Stimulus/controller; sem hide/show de painéis — a melhoria é **navegação por âncoras**, não abas dinâmicas (essas seguem opcionais no roadmap).
### Testes/validações
`bin/rails test` **274 runs / 1068 assertions / 0** falhas; rubocop **132/0**; brakeman **0**; bundler-audit **0**. Smoke real: `/tasks` 200; task vinculada → âncoras + "Conversas (1)" + soon sem href + `#tab-conversas` com MedPlus e "Ver"; task sem vínculo → âncora presente, sem contagem, "Nenhuma conversa vinculada".
### Fora de escopo (cumprido)
Sem JS/abas dinâmicas, sem controller/model/policy/rota/schema; sem alterar fluxo/redirect da F5.3, ConversationLink, `/conversations`, MarkdownRenderer/PiiRedactor; sem dashboard/Ctrl+L/scorer/busca/tags/inbox; `_origem/`/`_mockup/` intocados.

## 2026-06-19 — [Fase 5 · F5.4] Lista de conversas acionável / status de vínculo (CV-04) — CONCLUÍDO
### Resumo
`/conversations` ganha **status de vínculo por linha** e **filtro por vínculo**, virando uma lista de triagem leve (sem inbox/lote/atalhos — isso segue UI-05/v1). **Não carrega turnos** (LazyLoader não é chamado). Eager loading evita N+1.
### Entregue
- **Coluna "Vínculo"** (helper `ConversationsHelper#link_status_badge`, seguro: `content_tag`/`link_to`/`safe_join`, sem `html_safe`/`raw`/`sanitize`):
  - **Sem vínculo** → badge + ação rápida **"Criar tarefa"** (GET → `new_conversation_task_path`, fluxo F5.3);
  - **Primária** → badge `info` linkando à task (título); **"+N menção"** se houver menções adicionais;
  - **Menção (N)** → quando só há menções.
- **Filtro `link`** (`none`/`primary`/`mention`) via subquery em coluna indexada; semântica "mention" = possui ≥1 menção (mesmo com primária).
- **Eager loading** `includes(conversation_links: :task)` **só na coleção paginada** (`@total_count` sem includes).
### Testes/validações
`bin/rails test` **272 runs / 1047 assertions / 0** falhas; rubocop **132/0**; brakeman **0**; bundler-audit **0**. Guarda de N+1: vínculos carregados em **1 query** (preload), não por linha. Smoke real: `/conversations` 200; `?link=primary` → 1 conversa (badge linka à task); `?link=none` → 1634; `?link=mention` → 0 (sem menções nos dados reais); ação "Criar tarefa" nas não-vinculadas; teste read-only verde.
### Fora de escopo (cumprido)
Sem migration/schema/model/policy/rota; sem inbox de triagem (UI-05), tags, arquivos alterados, dashboard, Ctrl+L, scorer, busca avançada, abas reais — seguem como F5.5+/F6/roadmap. Sem alterar import/sync, MarkdownRenderer/PiiRedactor, fluxo F5.3, `_origem/`/`_mockup/`.

## 2026-06-18 — [Fase 5 · F5.3] Criar tarefa a partir da conversa (UI-10) — CONCLUÍDO
### Resumo
Fecha o loop **Conversa → Tarefa**: na conversa, ação "Criar tarefa desta conversa" abre form de nova tarefa (título pré-preenchido); ao salvar, cria a `Task` **e** o `ConversationLink` `primary`/`manual` **na mesma transação** (sem tarefa órfã). Antes só era possível vincular a tarefa **já existente**.
### Entregue
- **Rota aninhada:** `GET/POST /conversations/:conversation_id/tasks` (`new`/`create`) → `ConversationTasksController` (novo).
- **`conversation_tasks/new.html.erb`** (novo): reusa `tasks/_form` com `url:` opcional + título sugerido (`conversation.title` ou `"Conversa <8 chars>"`).
- **`tasks/_form.html.erb`**: aceita `url:` opcional (backward-compatible com `/tasks/new`).
- **`conversations/show.html.erb`**: ação "Criar tarefa desta conversa" no bloco Vínculos, **oculta quando já há `primary`**; corrigido comentário obsoleto ("nenhum turno renderizado").
- Teste de integração `conversation_tasks_test` (8 casos).
### Transação e regras
- `Task.save!` + `ConversationLink.save!` em `ActiveRecord::Base.transaction` → falha do link faz **rollback total**; counters da task atualizados pelo `after_create` (mesma transação).
- **Conversa já com `primary`:** `new` redireciona à conversa com alert; `create` tem backstop pela validação `single_primary_per_conversation` (não cria 2ª task nem 2º primary).
- **Autorização:** `authorize @conversation (show?)` + `authorize @task (create?)` + `authorize @link (create?)` (ADR-014; sem policies novas).
- **Redireciona** para a task criada com notice "Tarefa criada e vinculada à conversa."
### Testes/validações
`bin/rails test` **264 runs / 1016 assertions / 0** falhas; rubocop **131/0**; brakeman **0**; bundler-audit **0**. Smoke real: `/conversations` 200; conversa com primary → ação oculta + `new` redireciona com alert; conversa sem vínculo → ação visível + `new` 200; `/tasks` 200; task vinculada mostra a conversa. **Sem mutação de dados reais no smoke** (apenas GET).
### Fora de escopo (cumprido)
Sem migration/schema/model/policy novos; sem alterar import/sync, markdown/render, PiiRedactor/MarkdownRenderer, `_origem/`/`_mockup/`.

## 2026-06-18 — [Fase 5 · F5.2] Markdown sanitizado no render read-only de turnos — CONCLUÍDO
### Resumo
O `text` do turno passa a ser renderizado como **markdown (GFM) → HTML sanitizado server-side** (ADR-012), via novo `ConversationTurns::MarkdownRenderer` (defesa em profundidade: `commonmarker` em modo seguro + `Rails::HTML5::SafeListSanitizer` por allowlist + hardening de links). `tool_input` **continua** texto literal em `<pre>` (sem markdown). PII é redigida **antes** do markdown. O componente/template **não** usam `html_safe`/`raw`/`sanitize` (delegam ao renderer) — **grep-guard mantido verde**.
### Entregue
- **Dependência:** `commonmarker 2.8.2` (GFM em Rust; 0 transitivas Ruby; `bundler-audit` 0).
- **`app/services/conversation_turns/markdown_renderer.rb`** (novo): `call(text)` → `Commonmarker.to_html(unsafe:false, escape:true)` → `SafeListSanitizer` (allowlist) → `harden_links` → **SafeBuffer**. Única fonte de `html_safe` de conteúdo de conversa.
- **`TurnListComponent`**: `turn_body_html(turn)` (PII → trunca → markdown seguro); `tool_input_text` inalterado.
- **Template**: `.turn__body.markdown` renderiza o SafeBuffer; `tool_input` em `<pre>` inalterado.
- **CSS** `.turn__body.markdown` (p/headings/listas/code/pre/blockquote/links/tabela/hr).
- Testes: `markdown_renderer_test` (21) + integração (markdown vira HTML; XSS neutralizado; PII não vaza; `tool_input` literal; grep-guard verde).
### Segurança (allowlist + links)
- **Tags:** `p br hr strong em b i del code pre blockquote ul ol li h1-h6 a table thead tbody tr th td`. **Atributos:** só `href rel target` (em `a`). **Sem** `img`/`script`/`style`/`class`/`id`/`on*`.
- **Links:** só `http`/`https`/`mailto` → `rel="nofollow noopener noreferrer"` + `target="_blank"`; demais esquemas (`javascript:`/`data:`) e âncoras vazias **viram texto** (href removido).
- **Raw HTML** da fonte (`<script>`/`<img onerror>`/`<svg onload>`/`<div on…>`) é **escapado** (texto inerte), não executado; **imagem markdown** (`![]()`) é removida.
### Limitações conhecidas
- Raw HTML perigoso é **neutralizado por escape** (visível como texto), não apagado — inerte, mas aparece como texto.
- Sem syntax highlight; sem imagens (remotas ou markdown); sem autolink de e-mail (e-mail já é redigido a `<EMAIL>`).
- Tabelas GFM **habilitadas** (sem atributos). Markdown só no `text` (nunca em `tool_input`).
### Testes/validações
`bin/rails test` **257 runs / 966 assertions / 0** falhas; rubocop **129/0**; **brakeman 0** (sem warning de HTML/sanitização); bundler-audit **0**. Smoke real `/conversations/cd086107…`: **200**, **50** turnos, "Página 1 de 4", sem `:stale`; markdown visível (27 `.markdown`, 17 `<strong>`, 25 listas, 8 `<code>`, 3 headings); **0** tags vivas perigosas; **0** href `javascript:`/`data:`; **0** vazamento de `/Users/`//`/home/`//`C:\Users`//`file:///`//e-mail//`Bearer <token>`.

## 2026-06-18 — [Fase 5 · F5.1.5] Redação de PII em `text`/`tool_input` no render de turnos — CONCLUÍDO (`821f495`)
### Resumo
Camada **conservadora e idempotente** de redação de PII/segredos no render **read-only** de turnos, via `ConversationTurns::PiiRedactor`, aplicada em `TurnListComponent#turn_text` e `#tool_input_text` **antes do truncamento**. Preserva ERB auto-escape; **sem** `html_safe`/`raw`/`<%==`/`simple_format`/markdown; `tool_input` segue como texto em `<pre>`. Recorte estrito ao render — **loader/builder/importers/schema/banco inalterados**.
### Entregue
- **`app/services/conversation_turns/pii_redactor.rb`** (novo, PORO `module_function call`): redige strings; idempotente (rodar 2× não degrada `<EMAIL>`/`<SECRET>`/`<USER>`).
- **`TurnListComponent`** (`turn_text`/`tool_input_text`) passam pelo redator antes de `truncate_bytes`.
- Testes: unit `test/services/conversation_turns/pii_redactor_test.rb` + integração de render em `conversation_turns_test.rb` (text/tool_input redigidos; XSS escapado; grep-guard mantido).
### Padrões cobertos
e-mail → `<EMAIL>`; `Bearer <token>` → `Bearer <SECRET>`; `token`/`api_key`/`secret`/`password`/`access_token`/`refresh_token` (querystring e JSON) → `chave=<SECRET>`; paths `/Users/<nome>`, `/home/<nome>`, `C:\Users\<nome>`, `C:/Users/<nome>`, `file:///Users…`, `file:///home…` → `…/<USER>`.
### Limitações conhecidas
Não exaustivo; **não** redige segredos soltos sem rótulo; **não** cobre CPF/telefone/IP nesta fatia; conteúdo-fonte (`sessions.jsonl`) permanece **read-only e inalterado**; redação aplicada **apenas no render** (não persistido).
### Testes/validações
`bin/rails test` **235 runs / 861 assertions / 0** falhas/erros/skips; rubocop **127/0**; brakeman **0**; bundler-audit **0**. Smoke real: `/conversations/cd086107…` → **200**, **50** `li.turn`, "Página 1 de 4", **sem `:stale`**; zero vazamento de `/Users/`//`/home/`//`C:\Users`//`file:///`//e-mail//`Bearer <token>` na página.
### Fora de escopo (cumprido)
Sem markdown/F5.2/busca/virtualização/scorer/auto-link/triagem/chat; sem alterar loader/builder/importers/schema/migration/banco/config/`.devstack`/deploy/credenciais; `_origem/`/`_mockup/` intocados.

## 2026-06-18 — [P0.1] Saneamento documental + índice de documentação — CONCLUÍDO (docs-only)
### Resumo
Correção de incoerências remanescentes pós-P0 e criação de um **índice oficial** da documentação para reduzir drift. Somente documentação; sem código/teste/banco/migration/deploy.
### Criado
- **`docs/INDEX.md`**: visão geral, lista dos docs oficiais + função, **fonte de verdade por assunto**, ordem/gatilhos de atualização, regra **histórico vs estado atual**, regra **anti-drift**, topologia de repositórios e links relativos.
### Corrigido em `FEATURE_MATRIX.md`
- **GOV-01:** "ADRs 001–017" → **001–021** (21 ADRs aceitos; confirmado por `app/docs/adr/*.md`).
- **GOV-05:** corpus "criação pendente" → **✅ Entregue** (`test/fixtures/normalized_corpus/`).
- **Nota da seção Conversas:** reescrita (não dizia mais "CV-02/05/06/07/08 Não iniciado" — agora reflete CV-02 infra/CV-05-06 parcial/CV-08 entregue/CV-07 F5.2).
- **OP-06 backup:** "Não iniciado" → **🟡 Parcial** (`pg_dump` manual pré-carga usado; automação/prod = F7).
- **UI-02/UI-03:** esclarecida ambiguidade vs WD-04 → **🟡 base entregue (CRUD/F2/F4); UI unificada final = F5**.
- **CV-11 (novo):** "Resolução de workspaces (`folder`)" ✅ Entregue (F3.3/ADR-020) — remove a dependência fantasma `WS-map` (LK-04 e UI-08 agora dependem de **CV-11**).
### Ajustado em outros docs
- `PROJECT_STATUS.md`: semáforo Testes (corpus criado; 225/811; lacunas PII/log/SimpleCov) e checklist "Corpus … criado".
- `MIGRATION_PLAN.md`: nota de que ADR-018–021 vieram após o baseline (ponteiro ao índice de ADRs).
### Preservado como histórico (não reescrito)
Entradas antigas do `DELIVERY_LOG` (incl. métricas "221/776" de entregas passadas e "ADRs 001–017 aceitos" da Fase 0) e os entregáveis da **Fase 0** no `ROADMAP` (001–017) — snapshots fiéis ao momento.
### Validações
`bin/rails test` 225/811/0; rubocop 125/0; brakeman 0; bundler-audit 0 (docs-only).
### Risco residual de doc
Cópia **legada** de `docs/` na raiz `c:\Sandbox\_omni` (pré-consolidação) pode estar desatualizada — fonte de verdade é `app/docs/` (registrado no `INDEX.md`/`CONSTRAINTS`).

## 2026-06-18 — [P0] Fechamento documental de F3/F4 (MVP) + consolidação de readiness de produção — CONCLUÍDO (docs-only)
### Resumo
Atualização **somente documental** refletindo o diagnóstico de readiness pós-F5.1.4: **F3 e F4 fechadas como MVP**, **F5 mantida aberta**, métricas de teste sincronizadas e **bloqueadores de produção (F7) consolidados**. Sem alterar código/testes/banco/containers; sem migration.
### Atualizado
- **F3/M3 → 🟢 MVP de metadados CONCLUÍDO** (sync real idempotente 1635; folders 86→3; `sync_runs`/`turn_sources` íntegros; índice de turnos + loader lazy). Pendências → roadmap: **OP-01, OP-03, CV-03, CV-10**.
- **F4/M4 → 🟢 MVP manual CONCLUÍDO** (`conversation_links` `primary`/`mention`, reversível/auditável, counters; LK-01/02/03/07/08). Pendências → v1: **scorer/sugestões/auto-link (LK-04/05), aceite em lote (LK-06), `time_entry_id`**.
- **F5/M5 → 🟡 ABERTA**: F5.1→F5.1.4 entregues (render read-only/paginação/escape/roles/`source_file` oculto/mount persistido/limpeza dev). Pendências F5.2+: **markdown (CV-07)**, code blocks, busca, virtualização, modal Ctrl+L (UI-09), criar tarefa de conversa (UI-10), dashboard (UI-01), **redação de PII em `text`/`tool_input`**.
- **Produção (F7) → 🔴 não exercida**: nova seção "Readiness de produção" no `PROJECT_STATUS.md` + bloco na Fase 7 do `ROADMAP.md` com os bloqueadores (`production.rb` não endurecido; schemas Solid cache/queue/cable; `cable.yml` Redis; Kamal ausente; admin seed; worker de jobs; `/normalized` em prod; pipeline Python; backup/restore/rollback; PII; mailer host). Registrada a entrada órfã `001 NO FILE` e o gap `timezone`/`locale` como não-bloqueantes.
- **Métricas sincronizadas:** referência de estado atual **221/776 → 225/811** (PROJECT_STATUS); entradas históricas do diário preservadas como snapshots.
### Arquivos
`docs/ROADMAP.md`, `docs/PROJECT_STATUS.md`, `docs/FEATURE_MATRIX.md`, `docs/F5_CONTRACT_DECISIONS.md`, `docs/DELIVERY_LOG.md`.
### Validações
`bin/rails test` 225/811/0; rubocop 125/0; brakeman 0; bundler-audit 0 (docs-only, sem mudança de código).
### Fora de escopo (cumprido)
Sem código/testes/banco/container/migration; sem deploy/credenciais; sem tocar `_origem/`/`_mockup/`; sem corrigir a órfã `001` (só registrada).

## 2026-06-18 — [Fase 5 · F5.1.4] Limpeza controlada dos resíduos sintéticos do DB dev — CONCLUÍDO (DB-only)
### Resumo
Remoção **cirúrgica e transacional** dos artefatos sintéticos criados por `rails runner` durante auditorias adversariais no DB de **desenvolvimento** (não havia poluição em test/prod). **DB-only:** nenhum arquivo de código/teste/schema alterado, sem migration, sem commit/push. Backup completo gerado antes.
### Operação
- **Backup:** `tmp/dev_backup_pre_f514_20260618_095619.sql` (31.000.634 bytes) — preservado e **gitignored**.
- **Transação guardada:** `BEGIN` → DELETEs por **IDs exatos** → verificação de contagens (`RAISE EXCEPTION`→`ROLLBACK` se divergisse) → `COMMIT` só com o alvo exato.
- **Removido:** `conversation_turn_refs` 9 · `turn_sources` 3 (`/tmp/s*.jsonl`) · `conversations` 3 (`tXSS/tXSS2/tXSS3`, `source='x'`) · `sync_runs` 3 (`/tmp`, `status=ok`, 03:59).
### Contagens (antes → depois)
`conversations` 1638→**1635** · `turn_sources` 4→**1** · `conversation_turn_refs` 129491→**129482** · `sync_runs` 8→**5** · `conversation_links` **1** (inalterado) · refs órfãs **0**.
### Validações
Conversa "Planejamento MedPlus" preservada: loader **`:ok`**, `total=177`, `mismatched=0`, refs=message_count=**177**; `/conversations/:id` renderiza **50 turnos** na pág.1, sem `:stale`. `/sync_runs` **sem** fontes `/tmp` (5 runs reais: 4× `summaries.jsonl /data` + 1× `sessions.jsonl /normalized`). turn_source real `/normalized/sessions.jsonl` (240.091.231 bytes, 129.482 refs) e link real (`cd086107` ↔ task `b497171d`) preservados. `git status --porcelain` permaneceu **vazio** durante a limpeza. Checks pós-registro: `bin/rails test` 225/811/0; rubocop 125/0; brakeman 0; bundler-audit 0.
### Fora de escopo (cumprido)
Sem alterar código/testes/schema; sem migration; sem markdown/scorer/triagem/chat; sem tocar loader/builder/importers nem `_origem/`/`_mockup/`. Backup não removido.

## 2026-06-18 — [Fase 5 · F5.1.3] Ocultar `source_file` em sync runs — CONCLUÍDO
### Resumo
Remove a exposição de caminho/host na tela de sync (`/sync_runs/:id`), sem tocar sync/import/loader/banco. Era a última exibição de `source_file` cru apontada no checkpoint.
### Entregue
- **Helper `safe_basename`** (`ApplicationHelper`): retorna só o **nome do arquivo** (basename), tratando separadores `/` e `\` e o esquema `file://`; `blank` → "—". Garante que `/normalized/…`, `/tmp/…`, `/home/…`, `C:\Users\…`, `file:///…` **nunca** apareçam.
- **`sync_runs/show.html.erb`**: linha "Arquivo" passa a usar `safe_basename(@sync_run.source_file)` (ex.: `sessions.jsonl`) em vez do caminho cru. Demais telas já usavam `source_label` (seguro); turnos de conversa já ocultavam `source_file`.
### Testes/validações
`bin/rails test` 225 runs/811 assertions/0 (+4); rubocop 0 (125 arquivos); brakeman 0; bundler-audit 0. Novos testes: `application_helper_test.rb` (basename/PII) + `sync_runs_test.rb` (path bruto não vaza). HTTP: `/sync_runs/:id` real → "Arquivo: sessions.jsonl"; resíduo `/tmp` → só `s…jsonl`; 0 vazamentos de `/normalized`//`/tmp`//`file://`. `/conversations/:id` segue `:ok` (sem stale).
### Fora de escopo (cumprido)
Sem markdown/scorer/triagem/chat; sem alterar loader/builder/importers; sem migration; sem limpar banco; sem tocar `_origem/`/`_mockup/`.

## 2026-06-18 — [Fase 5 · F5.1.2] Consolidação documental + persistência do runtime — CONCLUÍDO
### Resumo
Higiene pós-F5.1.1 e ambiente dev reproduzível, **sem alterar comportamento funcional**: registro da F5.1.1 nos docs, remoção de nota obsoleta, addendum ao ADR-013 (alinhar `personal` boolean + decisão b1), padronização de nome "Omni" e **persistência do mount `/normalized:ro`** no fluxo de subida do `omni_web`.
### Entregue (somente docs + toolchain dev)
- **Script oficial de subida** `.devstack/up.sh` (+ `.devstack/README.md`): recria o `omni_web` com `/app`, volume `omni_bundle`, **`/normalized:ro`**, rede `omni_net`, porta 3000 e `bin/rails server` — idempotente (cria rede se faltar; remove `server.pid` órfão). Paths overridáveis por env. **Não copia/versiona `sessions.jsonl`.**
- **Docs:** F5.1.1 registrada (DELIVERY_LOG/PROJECT_STATUS/ROADMAP/FEATURE_MATRIX/F5_CONTRACT); removida a nota "commit/push pendentes de revisão" (obsoleta — F5.1/F5.1.1 já publicadas).
- **ADR-013:** addendum documentando que a implementação usa **coluna boolean `conversations.personal`** (não há `status='personal'`) e a **decisão b1** (ocultar conteúdo de conversa pessoal, sem ownership/`user_id`); **policy inalterada**.
- **Nomenclatura:** "Omni/Continuity" → **"Omni"** em `README.md`, `CONSTRAINTS.md`, `MIGRATION_PLAN.md`, `F4_CONTRACT_DECISIONS.md`, `UI_COMPLIANCE_AUDIT.md` (apenas nomenclatura ativa; sem alterar decisões históricas).
### Validações
`bin/rails test` 221 runs/776 assertions/0; rubocop 124/0; brakeman 0; bundler-audit 0 (sem mudança de código de app). Runtime: `omni_web` recriado pelo `.devstack/up.sh` → `/normalized/sessions.jsonl` visível **read-only**; `/conversations/:id` ("Planejamento MedPlus") renderiza turnos com loader `:ok` (177), **sem `:stale`**.
### Fora de escopo (cumprido)
Sem markdown/scorer/auto-link/triagem/chat; sem alterar loader/builder/importers; sem migration; sem limpar banco; sem tocar `_origem/`/`_mockup/`; sem mudar comportamento das telas.
### Pendências (follow-ups)
Limpeza dos resíduos sintéticos do DB dev (3 conversas `tXSS*` + 3 turn_sources `/tmp` + 9 refs); redação de `source_file` em `sync_runs/show`; ampliar redação de PII em `text`/`tool_input`; F5.2 (markdown sanitizado).

## 2026-06-18 — [Fase 5 · F5.1.1] Correção de artefato ERB + destaque de role — CONCLUÍDO (`a01efbd`)
### Resumo
Correção pequena de render (read-only mantido). **Não** introduz markdown/feature.
### Entregue
- **Bug do artefato `). %>`:** o comentário ERB do componente continha a sequência `<%= %>`, cujo primeiro `%>` fechava o comentário cedo e vazava `). %>` como texto. Comentário reescrito (sem `<%= %>` interno) → artefato eliminado.
- **Visibilidade de role:** badge do turno passa a ter **cor por role** via allowlist (`ROLE_TONES`: user→info, assistant→violet, tool→neutral, system→warning) — valores fixos do mapa (sem injeção). Turnos `user` ficam visíveis/destacados.
### Alterações
`app/components/conversations/turn_list_component.rb` (+`ROLE_TONES`/`role_tone`) e `.html.erb` (comentário corrigido + `badge--<%= role_tone(turn.role) %>`). Sem tocar loader/builder/importers/CSS/schema.
### Validações
`bin/rails test` 221/776/0; rubocop 124/0; brakeman 0; bundler-audit 0. Browser real (177 turnos): artefato ausente; `user` na pág.1 com badge azul; "Página 1 de 4"; sem stale/PII/XSS.
### Diagnóstico associado
O `:stale` observado em browser era **operacional** (o `omni_web` não montava `/normalized`), não bug da F5.1 — resolvido montando o arquivo `:ro` (persistido na F5.1.2).

## 2026-06-18 — [Fase 5 · F5.1] Render read-only de turnos — CONCLUÍDO
### Resumo
UI **read-only** de turnos em `/conversations/:id`, consumindo `ConversationTurns::LazyLoader` (ADR-021) com render seguro (ADR-012). **Sem markdown, sem scorer/auto-link, sem chat/edição, sem persistir conteúdo.** Decisão `personal` = **b1** (ocultar conteúdo; sem dono/`user_id`; ADR-013 inalterado).
### Entregue (CV-05/CV-06/CV-08 parciais)
- `ConversationsController#show`: carrega turnos via loader; `TURNS_PER_PAGE = 50`; `limit` **fixo** + `offset` por página (`turn_page`); **b1**: conversa `personal` não chama o loader.
- **ViewComponent** `Conversations::TurnListComponent` (+ template): lista turnos com `role` (allowlist), `timestamp`, **texto auto-escapado** (`pre-wrap`), `tool_input` como **texto em `<pre>`** (`JSON.pretty_generate` com `rescue`+truncamento); trata `:ok/:empty/:stale/:not_found` e `mismatched`; paginação anterior/próxima.
- View `show`: seção "Conversa" (ou aviso de conversa pessoal); CSS de turnos em `application.css`.
- **CSP restrita** habilitada (`default_src :self`; `object_src :none`; `script_src/style_src :self`; `frame_ancestors :none`) com **nonce** (importmap).
- **Segurança:** só auto-escape do ERB; **proibidos** `html_safe`/`raw`/`<%==`/`simple_format`/`sanitize` (grep-guard de teste); **sem markdown** (F5.2); **sem auto-link**; **`source_file` oculto**.
- Lacuna coberta: **`test/policies/conversation_policy_test.rb`**.
### Alterações (repo app/)
`controllers/conversations_controller.rb`; `components/conversations/turn_list_component.{rb,html.erb}` (novos); `views/conversations/show.html.erb`; `assets/stylesheets/application.css`; `config/initializers/content_security_policy.rb`; testes novos (`integration/conversation_turns_test.rb`, `policies/conversation_policy_test.rb`) + atualizados (`integration/conversations_test.rb`, `integration/conversation_links_test.rb`); docs. **Sem migration/schema; sem alterar loader/builder/importers.**
### Testes/validações
`bin/rails test`: **221 runs, 776 assertions, 0 falhas/erros/skips** (+12). rubocop 0 (124 arquivos); brakeman 0; bundler-audit 0. Cobertura nova: render, **XSS escapado**, **grep-guard** anti-`html_safe`, paginação (`TURNS_PER_PAGE=50`), stale, sem-refs, **b1 personal oculto**, conteúdo-não-persistido, `source_file`/PII não vazados, `ConversationPolicy`. Validação real: conversa de **177 turnos** → loader `:ok`, render 50/página ("Página 1 de 4 · 177 turnos"), sem `<script>`/`onerror=` crus, sem vazar path/`Users`.
### Fora de escopo (cumprido)
Sem markdown/syntax-highlight/busca/virtualização; sem scorer/auto-link/suggestions; sem chat/edição/anotação; **sem persistir `text`/`tool_input`/payload**; loader/builder/importers inalterados; sem migration.
### Próximo passo
F5.2 (markdown sanitizado — ADR-012) e/ou ampliação de redação de PII em `text`/`tool_input`; ou F4 v1 (scorer).

## 2026-06-17 — [Pré-Fase 5 · Fatia] Índice de turnos + loader lazy — CONCLUÍDO
### Resumo
Implementada a infraestrutura de **índice de offsets** e **leitura lazy** de turnos (ADR-021), **sem importar conteúdo para o banco** e **sem UI**. Abre conversa → offsets → `seek` das linhas do `sessions.jsonl`. **Não persiste `text`/`tool_input`**; **não lê shards**; **não altera importers**; **não executa sync de summaries**.
### Entregue
- **Migration `CreateTurnIndex`**: `turn_sources` (fingerprint do arquivo: `size_bytes`/`source_mtime`/`content_hash`/`schema_version`/`status`/`indexed_at`; unique do fingerprint) + `conversation_turn_refs` (ponteiros: `turn_source_id`/`conversation_id`/`thread_id`/`line_no`/`byte_offset`/`role`/`ts`; **sem colunas de conteúdo**; FKs cascade; checks `byte_offset>=0`/`line_no>0`; unique `(turn_source_id,line_no)` e `(turn_source_id,conversation_id,line_no)`; índices `(conversation_id,line_no)`/`(thread_id,line_no)`).
- **Models** `TurnSource`/`ConversationTurnRef` (validações alinhadas aos checks).
- **`Sync::BuildConversationTurnRefs`**: streaming binário, captura `byte_offset` antes do `gets`, parse defensivo, extrai só `thread_id`/`role`/`timestamp`, resolve `Conversation` por hash pré-carregado, `insert_all` em lote, fingerprint (size+mtime+hash parcial cabeça/cauda+schema), **idempotente** (no-op se fingerprint igual), **rebuild total** se o arquivo muda (remove versão antiga em cascade); auditoria via `SyncRun` (label `sessions.jsonl`, separado de summaries).
- **`ConversationTurns::LazyLoader`**: refs por conversa ordenadas por `line_no`, verifica fingerprint (stale ⇒ não lê), `seek(byte_offset)`+`gets`, **valida `thread_id` lido**, `limit`/`offset`, **redige `raw_source_file` (`<USER>`)**, payloads só em memória, **sem full-scan**.
- **Rake** `sync:turn_refs[path]` (não toca `ImportSummaries`/`ResolveWorkspaceFolders`).
### Build real (development, `:ro`)
`sessions.jsonl` (240.091.231 bytes): `lines_processed=129500`, `refs_created=129482`, `skipped_no_thread=18`, `skipped_no_conversation=0`, `malformed_lines=0`, `distinct_threads=1635`, **`covered_conversations=1635/1635 (100%)`**, `status=partial` (18 linhas sem `thread_id`). Backup pré-migration: `tmp/dev_backup_pre_turnrefs_20260617_231035.sql`.
### Smoke do loader (conversa real)
Conversa "Planejamento MedPlus" (`thread claude-code:/96856917…`): `message_count=177` == **refs=177** (batem); `loader.status=ok`, `total=177`, `mismatched=0`; colunas das refs sem `text`/`tool_input`/`payload`.
### Testes/checks
`bin/rails test`: **209 runs, 715 assertions, 0 falhas/erros/skips** (+16, `test/services/turn_index_test.rb`). rubocop 0 (121 arquivos); brakeman 0; bundler-audit 0.
### Fora de escopo (cumprido)
Sem UI de mensagens; sem render/markdown/sanitização visual; sem F5; sem scorer/suggestions/auto-link; sem leitura de shards; sem persistir `text`/`tool_input`; sem alterar importers; sem sync de summaries.
### Próximo passo
F5 (UI de conversa) consumindo o loader, com render sanitizado (ADR-012); ou F4 v1 (scorer).

## 2026-06-17 — [Pré-Fase 5 · Decisão] ADR-021 — lazy-load de turnos via índice de offsets — DOCUMENTADO
### Resumo
Documentada (somente documentação; **sem código/migration/tabela/banco**) a estratégia para localizar e abrir turnos de conversa **sob demanda**, sem importar `sessions.jsonl` para o banco. Fecha a pendência prevista no ADR-018 ("decidir índice `thread_id→offset` antes da F5").
### Decisão (ADR-021 — Aceita)
- **Lazy-load por índice de offsets**; chave canônica **`thread_id`**; menor unidade indexável = **a linha** do `sessions.jsonl`; índice guarda **ponteiros, não conteúdo**; leitura futura por **`seek(byte_offset)`+`readline`**; **validar `thread_id` da linha lida**; **não assumir faixa única contígua**.
- Tabela futura sugerida `conversation_turn_refs` (conversation_id, thread_id, line_no, byte_offset, role, timestamp, source_fingerprint, indexed_at) — **conceitual, não criada**.
- **Fingerprint** do arquivo (size+mtime+hash parcial) para detectar índice obsoleto e reindexar.
- **Segurança:** conteúdo (`text`/`tool_input`/paths) **não confiável**; render/sanitização na **F5** (ADR-012); `tool_input` nunca HTML; `raw_source_file`/paths com usuário **redigidos `<USER>`**; `personal` respeitado (ADR-013).
### Base empírica (leitura de prontidão, somente leitura sobre `_origem/_repob`)
`sessions.jsonl`: NDJSON, UTF-8, ~229 MiB, 129.500 linhas; `thread_id` em toda linha; **cobertura 1635/1635** vs `conversations.thread_id`; relação conversa→turnos **1:N** (ex.: 177 turnos = `message_count`).
### Alterações realizadas (somente docs)
**Criados:** `docs/adr/ADR-021-lazy-load-turnos-via-indice-offsets.md`; `docs/F5_CONTRACT_DECISIONS.md` (contrato de fronteira inicial). **Atualizados:** `docs/ARCHITECTURE_DECISIONS_INDEX.md` (linha ADR-021 + refs ADR-009/018); `docs/F3_CONTRACT_DECISIONS.md` (§4 → ADR-021); `docs/ROADMAP.md` (Fase 5); `docs/FEATURE_MATRIX.md` (nota CV-02/05/06/07/08); `docs/PROJECT_STATUS.md`. Padronização de nome **"Omni"** nos cabeçalhos dos docs tocados.
### Escopo negativo (cumprido)
Sem `conversation_turn_refs`/`ConversationTurnRef`/`TurnIndexBuilder`/`TurnLoader`; sem rake de indexação; sem controller/view de turnos; sem migration/tabela; sem alterar código; sem alterar banco; sem importar turnos; sem executar sync; sem processar `sessions.jsonl` em massa.
### Próximo passo
Sob autorização: preparar a **fatia de implementação** do índice (build streaming + fingerprint + leitura lazy, sem UI), depois a **F5** (render sanitizado).

## 2026-06-17 — [Fase 4 · MVP] Vínculo manual conversa↔tarefa — CONCLUÍDO
### Resumo
MVP do vínculo conversa↔tarefa: uma conversa vira **evidência vinculada** a uma tarefa, de forma **manual, reversível e auditável**, com counters em Task. **Sem scorer, sem `conversation_suggestions`, sem auto-link** (adiados para a fatia v1). Sem turnos/conteúdo/F5.
### Features entregues (LK-01/02/03/07/08)
- **Tabela `conversation_links`** (uuid; FK `conversation`/`task` cascade; `link_type` ∈ {primary,mention}; `origin` ∈ {manual,auto,suggestion}; `confidence` 0..1 nullable; `created_by_id` **bigint** FK→users nullify; **unique parcial ≤1 primário por conversa**; unique triplo (conversation,task,link_type); CHECKs).
- **Model `ConversationLink`** (validações; primário exclusivo; counters **transacionais** em `after_create`/`after_destroy`).
- **Counters em Task** (`conversation_count`/`last_conversation_at`) recomputados a partir de vínculos **primary** de conversas **não-personal** (ADR-013) + rake **`tasks:recount_conversations`**.
- **Rotas aninhadas** `conversations/:conversation_id/links` (create/destroy) + `ConversationLinkPolicy` (ADR-014).
- **UI:** bloco "Vínculos" + form em `/conversations/:id` (com guarda de primário existente); aba "Conversas" **read-only** em `/tasks/:id` (lista vinculadas, sem turnos/conteúdo).
### Alterações realizadas (repo app/)
Migration `create_conversation_links`; `models/conversation_link.rb` + assoc/counters em `task.rb`/`conversation.rb`; `policies/conversation_link_policy.rb`; `controllers/conversation_links_controller.rb` (+ loads em `conversations`/`tasks` controllers); rotas; views (`conversations/show`, `tasks/show` aba); `lib/tasks/conversations.rake`; testes (model/policy/integration); `db/schema.rb`; docs. **Sem alterar importers; sem sync; sem ler sessions/shards/turnos.**
### Testes/validações
`bin/rails test`: 193 runs, 666 assertions, 0 falhas/erros/skips (+21). rubocop 0 ofensas (115 arquivos); brakeman 0; bundler-audit 0. Cobertura: primário exclusivo, mention permitido, duplicata triple bloqueada, validações, cascade, **counters** (create/remove/mention/personal), policy (auth/anon), integração (vincular/remover/aparecer nos dois lados), sem turnos/sessions/shards, sem rotas de suggestions/scorer. Backup pré-migration: `app/tmp/dev_backup_pre_f4_20260617_192531.sql`. Smoke dev (net-zero): counters 0→1→0; telas 200; `conversation_links=0` ao final.
### Pendências
**F4 v1:** `conversation_suggestions` + **scorer** (metadados; ≥0.85; aceite explícito; nunca auto-link sem aceite) + **auto-link** (LK-04/05) — quando houver tarefas reais; `time_entry_id` no link; render de conteúdo/turnos = F5. **Avaliar ADR** para auto-link/scorer na fatia v1 (não criado agora).
### Riscos
Nenhum novo. Domínio com poucas tarefas (dev) limita validação visual; counters protegidos por recompute + rake.
### Próximo passo
Decidir entre **F4 v1** (scorer/sugestões) e **Fase 5** (UI rica de conversa).

## 2026-06-17 — [Fase 3 · F3.UI.1] Console read-only de validação — CONCLUÍDA
### Resumo
UI **mínima e somente leitura** para validar visualmente os dados da Fase 3 (1635 conversas + sync runs). **É um console de validação, não a UI final da Fase 5.** Não renderiza turnos, não lê `sessions.jsonl`/shards, não cria vínculo conversa↔tarefa, não executa sync e não altera dados.
### Features entregues
4 telas read-only: `/conversations` (KPIs + filtros + tabela paginada manual 50/pág), `/conversations/:id` (**somente metadados**, sem turnos/conteúdo), `/sync_runs` (execuções + contadores), `/sync_runs/:id` (resumo + `sync_run_items`). Sidebar com grupo "Conversas" (Conversas + Sync). Filtros: source, com/sem título, com folder/órfão, busca por título/`thread_id`. KPIs: total, workspaces resolvidos/órfãos, sem título, último sync, skipped/erros.
### Alterações realizadas (repo app/)
Novos: `controllers/{conversations,sync_runs}_controller.rb`, `policies/{conversation,sync_run}_policy.rb`, `views/conversations/{index,show}`, `views/sync_runs/{index,show}`, testes de integração. Alterados: `config/routes.rb` (`resources … only: %i[index show]`), `SidebarComponent`, `application_helper.rb` (tons `ok/partial/error`), `application.css` (`.filters/.pagination/.mono`). **Sem migration/schema/model; sem importer/sync.**
### Segurança/escopo
Tudo via ERB **auto-escapado** (sem `html_safe`, sem markdown, sem conteúdo de conversa); rotas só `index/show` (sem `new/edit/create/update/destroy`); read-only (sem edição/exclusão/reprocessamento).
### Testes/validações
`bin/rails test`: 172 runs, 599 assertions, 0 falhas/erros/skips (+10). rubocop 0 ofensas (107 arquivos); brakeman 0; bundler-audit 0. Smoke autenticado: 4 telas 200; KPIs reais (1635/83); show sem `<table>` de conteúdo.
### Pendências
UI rica de conversa (render de turnos/markdown), vínculo conversa↔tarefa, triagem/sugestões, scorer → **Fase 4/5** (fora). 
### Riscos
Nenhum novo.
### Próximo passo
Decidir entre **Fase 4** (vínculo conversa↔tarefa) e refinamentos do console.

## 2026-06-17 — [Fase 2 · M2] Domínio concluído — migração de dados reais N/A
### Resumo
Encerramento do **M2**: o domínio de trabalho está **completo por modelagem/CRUD** (WD-01..07) e a **migração de dados reais de domínio é N/A**, porque a aplicação de origem (RepoA) estava **inativa** e o snapshot real não tem massa histórica.
### Evidência (leitura de prontidão do M2)
Restauração **read-only** do único snapshot real conhecido (`_origem/_repoa/postgres-volume-snapshot-20260328.tgz`, volume **Postgres 16**, DB `app_v2`) em container **descartável** (já removido; `_origem` intocado). Contagens verificadas na origem:
- `clients=0`, `contacts=0`, `projects=0`, `tasks=0`, `demands=0`, `time_entries=0` (domínio **vazio**);
- `users=2` (contas de teste de app inativa).
### Decisão
- **M2 concluído** pela modelagem/CRUD (clients/contacts/projects/tasks/demands/time_entries + ConvertDemand + `/tasks/:id`, com testes).
- **Migração histórica de domínio = N/A** (origem vazia / app inativo). Não há `contagens origem×destino` a validar.
- **Usuários do snapshot (2) não migrados** — contas de teste/inativas; o app já possui o usuário `demo`.
- Não houve migração real de dados de domínio. Os **dados reais efetivamente disponíveis** no projeto hoje são os **metadados de conversas** importados na F3 (1635 conversas).
### Alterações realizadas (repo app/)
Somente documentação: `PROJECT_STATUS.md` (M2 concluído; semáforo Repo A 🟢; checklist), `ROADMAP.md` (Fase 2 ✅ / marco M2 ✅, dados N/A), `FEATURE_MATRIX.md` (nota WD), `MIGRATION_PLAN.md` (matriz de domínio N/A), este log. **Sem código/migrations/schema/banco; sem import; sem migração de usuários.**
### Testes/validações
N/A (somente docs). Banco dev inalterado.
### Pendências
Nenhuma para o M2. Próximo foco (a decidir): tela read-only de Conversas/Sync (validação visual) ou **Fase 4** (vínculo conversa↔tarefa).
### Riscos
Nenhum. O plano de migração permanece como referência caso surjam dados de domínio no futuro.
### Próximo passo
Escolher entre tela read-only de Conversas/Sync e Fase 4.

## 2026-06-17 — [Fase 3 · F3.3] Resolução de folders de workspace — CONCLUÍDA (development)
### Resumo
Resolveu `workspace_maps.folder` a partir dos `workspace.json` reais do RepoB. **Exceção controlada ao ADR-008**: lê **somente** o mapa `workspace_hash → folder` da área `raw/.../workspaceStorage/<hash>/workspace.json` em **modo leitura (`:ro`)** — **não** lê conversas/turnos/`sessions.jsonl`/shards e **não** executa o pipeline.
### Features entregues
- **Serviço** `Sync::ResolveWorkspaceFolders`: lê `<base>/<hash>/workspace.json`; hash = nome da pasta; parse defensivo; decodifica URI (`file:///c%3A/AtivaLocal` → `c:/AtivaLocal`); **redige usuário** em paths sob `Users/<nome>` → `<USER>` (privacidade no banco); **atualiza só `WorkspaceMap` existentes** (não cria os extras do snapshot); pula `workspace.json` sem `folder`; idempotente; relatório (`scanned/resolved/updated/unchanged/not_found_in_db/skipped_without_folder/errors`).
- **Rake** `bin/rails 'sync:workspace_folders[path]'`.
### Alterações realizadas (repo app/)
`app/services/sync/resolve_workspace_folders.rb` (novo); `lib/tasks/sync.rake` (+task); `test/services/sync/resolve_workspace_folders_test.rb` (novo); docs (`F3_CONTRACT_DECISIONS.md` §6, este log, `PROJECT_STATUS.md`, `ROADMAP.md`). **Sem migrations/schema/models/UI.**
### Execução real (development)
Fonte: `raw/snapshot_20260616_112333/workspaceStorage` (`:ro`); backup `app/tmp/dev_wsmaps_backup_pre_f33_20260617_161045.sql`. 1ª execução: `scanned=98, resolved=83, updated=83, unchanged=0, not_found_in_db=11, skipped_without_folder=4, errors=0`. 2ª (idempotente): `updated=0, unchanged=83`. **`orphan` 86 → 3** (resíduo = `workspace.json` sem `folder`); `WorkspaceMap=86` (sem novos). `Conversation.count=1635`, `SyncRun.count=4`, domínio **inalterados**. **0** folders com usuário cru; `<USER>` aplicado.
### Testes/validações
`bin/rails test`: 162 runs, 555 assertions, 0 falhas/erros/skips. rubocop 0 ofensas (101 arquivos); brakeman 0; bundler-audit 0. Teste do serviço cobre: decodificação URI, redação de home, update-only, não-cria-extra, pula sem-folder, idempotência, parse defensivo.
### Pendências
3 workspaces permanecem órfãos (sem `folder` no `workspace.json`). **M3 segue parcial** (metadados + folders; módulo completo de conversas — turnos/UI/vínculo — fora, F4/F5). Possível **ADR-020** para formalizar a exceção ao ADR-008 (sugerido, não criado).
### Riscos
Nenhum novo. Exceção ADR-008 é controlada (read-only, só hash→folder).
### Próximo passo
Registrado. Depois: ADR-020 (se desejado) e/ou migração de dados reais do domínio (M2 pleno) e/ou Fase 4 (vínculo).

## 2026-06-17 — [Fase 3 · F3.2 + F3.2.1] Primeiro sync real de summaries + correção do merge — CONCLUÍDAS e PUBLICADAS
### Resumo
Primeiro **sync real controlado** de `summaries.jsonl` (metadados de conversa) em `development`, e a correção **F3.2.1** de um bug de merge exposto pelo dado real. Publicado até o commit **`bd0a9ce`**. **Só metadados** — turnos/`sessions.jsonl`/shards/UI/vínculo continuam fora (ADR-018).
### Execução (F3.2)
- Ambiente **`development`**; origem montada **read-only/allowlist**: apenas `summaries.jsonl` + `session_titles.json` expostos ao container (`sessions.jsonl`/shards/`tags.json` **fisicamente fora**; pipeline do RepoB **não** executado).
- **Backup** prévio: `app/tmp/dev_sync_backup_pre_f32_20260617_151436.sql` (não versionado).
- **1ª execução:** `lines_processed=2399, imported=1635, updated=0, skipped=1, error_lines=0, status=partial`. O `partial` é **esperado** e explicado por **1 linha sem `thread_id`** (auditável em `sync_run_items`).
- **2ª execução (idempotência):** `imported=0, updated=1635, Conversation.count=1635`.
- **Domínio preservado:** clients/projects/tasks/demands/time_entries/users inalterados.
### Achado e correção (F3.2.1, commit `bd0a9ce`)
- **Achado:** 1069/1635 conversas ficaram com `source`/`workspace_hash`/`title` nulos — porque muitos registros reais (`chat_editing_state`, `agent_sessions`) têm `last_ts = nil`, e o `fold` só atribuía escalares na linha estritamente mais nova → divergia da regra documentada (empate → ordem de leitura; todos nulos → 1ª linha vence).
- **Correção (apenas `import_summaries.rb` + teste):** 1ª linha vence quando não há vencedor; **backfill** (`fill-if-empty`) de escalares nulos em registros existentes; não sobrescrever valor presente por nil. Regra do contrato **não mudou** — só a implementação passou a respeitá-la. +3 testes de regressão (`last_ts` nulo; misto; backfill).
- **Re-sync pós-patch (idempotente):** `Conversation.count=1635`, **`source_nil` 1069→0**, **`workspace_hash_nil`=13** (legítimos do dado), **`title_nil`=1067** (limitação do dado de origem — **não é bug**), `WorkspaceMap=86` (**todos órfãos**; resolução de `folder` → F3.3).
### Alterações realizadas (repo app/)
F3.2 = execução operacional (sem código). F3.2.1 (`bd0a9ce`): `app/services/sync/import_summaries.rb` + `test/services/sync/import_summaries_test.rb`. **Sem migrations/schema/models/UI/docs no commit do fix.**
### Testes/validações
`bin/rails test`: 161 runs, 541 assertions, 0 falhas/erros/skips. rubocop 0 ofensas; brakeman 0; bundler-audit 0.
### Pendências
**M3 parcial:** sync real de **metadados** entregue; **módulo completo de conversas (turnos, UI, vínculo conversa↔tarefa, triagem) fora** (F4/F5). **F3.3** (resolver `workspace_maps.folder` a partir de `raw/.../workspace.json`) pendente. Banco dev mantém `sync_runs=4`/`sync_run_items=4` como evidência de auditoria.
### Riscos
Nenhum novo. `title_nil=1067` é característica do dado de origem (registros sem título), não defeito.
### Próximo passo
Registrado (esta entrada). Depois: autorizar **F3.3** ou a migração de dados reais do domínio (M2 pleno).

## 2026-06-17 — [Fase 3 · F3.1] Migrations + importer idempotente de summaries — CONCLUÍDA e PUBLICADA
### Resumo
Primeiro código da Fase 3: **metadados de conversa** a partir da saída normalizada do RepoB (ADR-008), **idempotente por `thread_id`** e em **streaming**. **Apenas summaries/metadados** — turnos/`sessions.jsonl`/shards continuam fora (ADR-018). Publicado em `origin/main` no commit **`fe291d9`** (`fe291d99b3d614458b08d409a85cc9b0d8c4b51b`).
### Features entregues
- **Tabelas:** `conversations`, `workspace_maps`, `sync_runs`, `sync_run_items` (todas uuid PK).
- **Serviço:** `Sync::ImportSummaries` (streaming linha-a-linha; `JSON.parse` defensivo; merge determinístico por `thread_id` — min `first_ts`/max `last_ts`/max contadores/união ordenada de `files_changed`/`source`+`workspace_hash`+título-fallback da linha de maior `last_ts`; título canônico de `session_titles.json` sobrescreve; upsert idempotente; `sync_run` + `sync_run_items` só para linhas problemáticas).
- **Rake:** `bin/rails 'sync:summaries[path]'` (entrada operacional simples; sem job/agendamento).
- **Fontes consumidas:** `summaries.jsonl`, `session_titles.json`, `workspace_maps.json`. **`sessions.jsonl`/shards/turnos NÃO** (ADR-018).
- **`workspace_maps`:** órfão = `folder IS NULL` (scope `WorkspaceMap.orphan`).
- **`conversations.user_id` = `bigint`** (segue `users.id`, que é bigint/Devise), FK local `ON DELETE SET NULL`, nullable, sem enforcement (prep ADR-013/014); **não é ID externo** do RepoA/RepoB. `personal boolean default false` (prep).
### Alterações realizadas (repo app/, commit fe291d9)
4 migrations (`create_conversations`/`create_workspace_maps`/`create_sync_runs`/`create_sync_run_items`); models `Conversation`/`WorkspaceMap`/`SyncRun`/`SyncRunItem`; `app/services/sync/import_summaries.rb`; `lib/tasks/sync.rake`; testes model + serviço; `db/schema.rb`; nota em `docs/F3_CONTRACT_DECISIONS.md` (§5, `user_id` bigint). **Sem UI/controller/rota; sem FK conversa↔task/time_entry; sem scorer/link.**
### Testes/validações
`bin/rails test`: 158 runs, 522 assertions, 0 falhas/erros/skips. rubocop 0 ofensas (99 arquivos); brakeman 0 avisos; bundler-audit 0 vulnerabilidades. **Smoke da rake apenas com o corpus sintético** (`test/fixtures/normalized_corpus/`): 1ª execução `imported=2`; 2ª `imported=0/updated=2` (idempotência); `conversations=2`, `workspace_maps=2` (órfãos=1), status `partial` (1 linha malformada → `error_lines=1`). **Nenhum dado real importado.**
### Pendências
**F3.2** (sync real de `summaries.jsonl` do `output/normalized/`, com backup/`pg_dump` e allowlist de caminho — ADR-011) **aguarda autorização**. Banco de **desenvolvimento** contém registros **sintéticos** do smoke (`conversations=2`, `workspace_maps=2`, `sync_runs=2`, `sync_run_items=2`) — **a limpar antes da F3.2**. Turnos lazy (decisão antes da F5). **M3 NÃO concluído** (falta sync real/validação com dados reais). F4/F5 não iniciadas.
### Riscos
Nenhum novo.
### Próximo passo
Limpeza do banco de dev + leitura de prontidão da **F3.2** (ambas sob autorização).

## 2026-06-17 — [Fase 3 · F3.0] Pré-requisitos, contrato e corpus — CONCLUÍDA (preparação, sem implementação)
### Resumo
Etapa de **preparação** da Fase 3 (sync de conversas), **somente governança/contrato/corpus** — **sem código**: nenhuma migration/model/importer/sync, nenhum dado real importado. Endereça os três pré-requisitos bloqueantes da F3. Contexto: o projeto foi consolidado em **repositório único** (`app/`, ADR-019) e publicado em `origin/main` (`https://github.com/jesustdmen/omni.git`); governança agora vive em `app/docs/`.
### Features entregues
Nenhuma feature de software. Artefatos: **ADR-018** (addendum ao ADR-009 — a regra `thread_id → shards/messages/<sha1>` foi **refutada**; shard = `sha1("v4:<file_type>:<source_path>")`; turnos e `sessions.jsonl` **fora da F3**; lazy-load decidido antes da F5). **`docs/F3_CONTRACT_DECISIONS.md`** (decisões: `schema_version` por-run no Rails + parsing defensivo; `thread_id` text+unique; **regra determinística de merge** por `thread_id`; turnos fora da F3; `user_id` nullable + `personal` default false como preparação futura, sem enforcement). **Corpus sintético** em `test/fixtures/normalized_corpus/` (3 válidas + 1 malformada + 2 com mesmo `thread_id`; UUID e sha1/40-hex; título canônico via `session_titles.json` e fallback; workspace conhecido + órfão; `tags.json`; `sessions.jsonl` documental).
### Alterações realizadas (repo app/)
Criados: `docs/adr/ADR-018-addendum-adr-009-shards-turnos-lazy.md`, `docs/F3_CONTRACT_DECISIONS.md`, `test/fixtures/normalized_corpus/{README.md,summaries.jsonl,session_titles.json,workspace_maps.json,tags.json,sessions.jsonl}`. Atualizados: `docs/ARCHITECTURE_DECISIONS_INDEX.md` (ADR-018 antes da ADR-019), `docs/PROJECT_STATUS.md`, `docs/FEATURE_MATRIX.md`, `docs/DELIVERY_LOG.md`. **ADR-019 não renumerada nem alterada.**
### Testes/validações
`bin/rails test`: 137 runs, 0 falhas. rubocop 0 ofensas; brakeman 0 avisos; bundler-audit 0 vulnerabilidades. (Artefatos de F3.0 são docs/fixtures; sem novos testes de código — a suíte da F3.1 usará o corpus.)
### Pendências
**F3.1** (migrations `conversations`/`workspace_maps`/`sync_runs`/`sync_run_items` + importer idempotente de `summaries.jsonl`) **aguarda autorização**. Turnos (F5). Migração de dados reais (M2 pleno) pendente.
### Riscos
Nenhum novo. `_SHARD_SCHEMA_VERSION` do RepoB pode mudar (hoje "4") — tratado como versão de contrato por-run.
### Próximo passo
Autorização para **F3.1**.

## 2026-06-17 — [Fase 2 · F2.5] TimeEntry (+conversation_id) — CONCLUÍDA
### Resumo
Quinto e último recorte do domínio de trabalho: `TimeEntry` (WD-07), do zero em Rails, conforme docs oficiais e a leitura de prontidão aprovada. **Fecha o CRUD do domínio da Fase 2.** Sem cronômetro/start-stop/cálculo automático; conversas/vínculo/sync/scorer fora do recorte.
### Features entregues
WD-07 TimeEntry: CRUD; `belongs_to :task` (FK **ON DELETE CASCADE**) + `Task has_many :time_entries, dependent: :destroy`; campos `start_time`/`end_time` (timestamptz), `duration` (integer default 0, **CHECK >= 0**), `date`, `is_running` (default false), `description`; **`conversation_id` uuid nullable, SEM FK e SEM lógica** (preparação F3/F4 — fora de params/forms). `Task#total_duration` (soma read-only). Rota **top-level `resources :time_entries`** (+ item "Time entries" na sidebar). Aba "Time entries" em `/tasks/:id` **read-only** (lista + total) com link "Novo apontamento" pré-preenchendo a task. **`duration` mantido como inteiro cru** (paridade RepoA); sem timer/auto-cálculo.
### Alterações realizadas (repo app/, commit 244116b)
Migration create_time_entries; model TimeEntry; edits Task (has_many + `total_duration`); TimeEntryPolicy (ADR-014); TimeEntriesController; rota `resources :time_entries`; SidebarComponent (item "Time entries"); views ERB (index/show/new/edit/_form); aba real read-only em tasks/show; regra CSS `.te-total`. 19 arquivos.
### Testes/validações
`bin/rails test`: 137 runs, 454 assertions, 0 falhas/erros/skips. rubocop 0 ofensas (84 arquivos); brakeman 0 avisos; bundler-audit 0 vulnerabilidades. Cobertura: model (task/start_time/date obrigatórios, duration ≥ 0, defaults, end_time opcional + ordem, **cascade**, `total_duration`, `conversation_id` existe/nil), policy (auth/anon/scope), integration CRUD completo, `new` pré-seleciona task, erro com `div.errors`, **`conversation_id` não atribuível via params**, **aba Time entries em `/tasks/:id` com lista read-only + total**. Smoke pós-deploy (login real): telas 200.
### Pendências
**M2 pleno** (contagens origem×destino) pendente de **migração/validação de dados reais** — não autorizada; **M2 não declarado 100% fechado**. Conversas/sync/scorer/vínculo/Fase 5 não iniciados. `conversation_id` recebe FK/lógica só em F3/F4.
### Riscos
Nenhum novo.
### Próximo passo
Fase 3 (sync de conversas) **com pré-requisitos** (corpus, validação `thread_id→shard`, `schema_version`) — não iniciar sem autorização e sem os pré-requisitos. Alternativa: planejar a migração de dados reais (autorização + backup) para fechar o M2 pleno.

## 2026-06-17 — [Fase 2 · F2.UI] Baseline visual hi-fi — APROVADA (baseline provisório)
### Resumo
Etapa **exclusivamente de apresentação visual** sobre as telas já existentes (F2.1–F2.4), elevando o app de scaffolding para uma linguagem SaaS limpa inspirada nos hi-fi (sidebar clara, topbar, cards brancos com borda sutil, badges/pílulas, abas horizontais, tabelas com respiro). **Não é a UI final**: a UI unificada real continua sob responsabilidade da **Fase 5** (UI-01..UI-11). Nenhuma feature nova; sem mudança de domínio/migrations/comportamento.
### Features entregues
**Nenhuma feature de domínio nova.** Melhoria visual de: layout/shell, sidebar (ViewComponent, agrupada e clara), topbar com busca **apenas visual** (placeholder, sem backend), flash, dashboard (callout de triagem placeholder + cards métricos com **contagens reais** + "tarefas recentes" reais + painel de conversas placeholder), clients/contacts, projects, tasks, `/tasks/:id` (breadcrumb/badges/abas placeholder), demands, fluxo visual de ConvertDemand, formulários, tabelas/listas, estados vazios e blocos de erro. Helper `status_badge` (pílulas) escrito do zero.
### Alterações realizadas (repo app/, commit 3d5d8e4)
26 arquivos, só apresentação: `app/assets/stylesheets/application.css` (design system próprio — sem Tailwind/Bootstrap/dependências/fontes externas; `system-ui`); `views/layouts/application.html.erb` (shell + topbar + flash; **correção do link do CSS** `:app`→`application`, que apontava para um `app.css` inexistente; rodapé com logout funcional); `SidebarComponent` (.rb/.html.erb) agrupada/clara; `application_helper.rb` (`status_badge`); `dashboard_controller.rb` (**somente leitura** de contagens já existentes); views de clients/contacts/projects/tasks/demands (index/show/new/edit), dashboard e placeholder. **Sem migrations, sem rotas novas, sem mudança de model/policy.** Nada copiado dos hi-fi/`_origem`/`_mockup` (apenas referência visual).
### Testes/validações
`bin/rails test`: 112 runs, 376 assertions, 0 falhas/0 erros/0 skips. rubocop 0 ofensas (77 arquivos); brakeman 0 avisos; bundler-audit 0 vulnerabilidades. **Seletores de teste preservados** (`h1`, `form`, `table`, `td`, `dd`, `li` de contatos, `div.errors`, `.tab`, `.convert`, `.converted-state`, selects por `name`). Smoke pós-deploy (login real via HTTP): todas as telas autenticadas 200 com o shell novo. **Validação visual manual realizada e aprovada pelo usuário** como baseline provisório.
### Pendências
UI final = **Fase 5** (UI unificada real). Sem conversas reais/aba Conversas real/sync/scorer/vínculo conversa↔tarefa/inbox/triage real/command palette/modal Ctrl+L/diário/handoff. **TimeEntry (F2.5) segue não iniciado.** Abas da Task (exceto Detalhes) e busca da topbar são placeholders visuais sem lógica. Migração de dados reais segue não autorizada.
### Riscos
Nenhum novo. Abas sem switching JS (apenas "Detalhes" visível) e busca inerte — intencional nesta fase.
### Próximo passo
Leitura de prontidão da **F2.5 (TimeEntry)** e autorização para iniciá-la.

## 2026-06-16 — [Fase 2 · F2.4] Demand + ConvertDemand transacional — CONCLUÍDA
### Resumo
Quarto recorte do domínio: `Demand` (WD-05) + conversão demanda→tarefa **transacional** (WD-06), do zero em Rails/Hotwire, conforme docs oficiais. Corrige o gap não-atômico do RepoA. TimeEntry/conversas/FK demand↔task fora do recorte.
### Features entregues
WD-05 Demand: CRUD; `belongs_to :client, optional` (FK nullify) + `Client has_many :demands, dependent: :nullify`; enums fechados origin (`phone/email/meeting/chat/whatsapp/other`), priority (`low/medium/high`), status (`pending/converted`, default pending) + CHECK; `converted_at`. WD-06 `ConvertDemand` (command object) **atômico** (`ActiveRecord::Base.transaction`): cria Task (`type=support`, `status=pending`, mesmo cliente/título/descrição) + marca demanda `converted`/`converted_at`; guardas (sem cliente / já convertida) → erro controlado, sem efeitos; retorna a task para redirect/flash. **Sem FK demand↔task** (paridade, confirmado).
### Alterações realizadas (repo app/, commit d4c6f35)
Migration create_demands; model Demand; edit Client (has_many :demands); `app/services/convert_demand.rb`; DemandPolicy (+`convert?`); DemandsController (+`convert`); rota `resources :demands do post :convert, on: :member end` (sidebar "Demandas" ativa); views ERB (com botão "Converter em tarefa" só quando pending).
### Testes/validações
`bin/rails test`: 112 runs, 376 assertions, 0 falhas/erros. rubocop 0 ofensas; brakeman 0 avisos; bundler-audit 0 vulnerabilidades. Inclui **teste de atomicidade** (rollback completo via override de singleton em `demand.update!`: Task.count inalterado, demanda permanece pending, converted_at nil) + CRUD + convert (sucesso/sem-cliente/já-convertida) + visual-funcional.
### Pendências
TimeEntry (F2.5, encerra M2). Conteúdo real da aba "Demanda" na task e vínculo demand↔task → decisão futura. Migração de dados reais segue não autorizada.
### Riscos
Nenhum novo.
### Próximo passo
Autorização para F2.5 (TimeEntry).

## 2026-06-16 — [Fase 2 · F2.3] Task base + página /tasks/:id — CONCLUÍDA
### Resumo
Terceiro recorte do domínio: `Task` base (WD-04) + página `/tasks/:id`, do zero em Rails/Hotwire, conforme docs oficiais e ADR-016 (paridade + counters; campos de v1 adiados). Demand/ConvertDemand/TimeEntry/conversas fora do recorte.
### Confirmação sobre `type` (referência RepoA)
Lista fechada confirmada no validator do servidor (`server/src/validators/tasks.ts`): `support`, `question`, `implementation`, `development`, `commercial`. (Front legado usa `questions` no plural — divergência conhecida; adotado o valor do servidor, que persiste.) → select + inclusão.
### Features entregues
WD-04 Task base: CRUD; `belongs_to :client` (FK cascade) + `belongs_to :project, optional` (FK nullify); `Client has_many :tasks (destroy)`, `Project has_many :tasks (nullify)`; `status` string + Rails enum (default `todo`, validate) + CHECK constraint; `type` string com lista fechada (STI desabilitado via `inheritance_column = :_type_disabled`); counters `conversation_count`(0)/`last_conversation_at`(nil) como colunas (sem lógica); validação de mesmo-cliente entre task e project. Página `/tasks/:id` com aba **Detalhes** real + abas **placeholder** (Conversas/Time entries/Histórico/Demanda).
### Alterações realizadas (repo app/, commit d1f502c)
Migration create_tasks; model Task; edits Client/Project (has_many :tasks); policy TaskPolicy; TasksController; rota `resources :tasks` (substitui placeholder; sidebar "Tarefas" ativa); views ERB (index/show com abas/new/edit/_form).
### Testes/validações
`bin/rails test`: 82 runs, 259 assertions, 0 falhas/erros. rubocop 0 ofensas; brakeman 0 avisos; bundler-audit 0 vulnerabilidades. Cobertura inclui: presença title/type/status, status default/inclusão, counters default, project opcional, cascade (cliente) e nullify (projeto), mesmo-cliente, STI desabilitado, policy/scope, CRUD completo e visual-funcional (selects, erro, `/tasks/:id` com abas).
### Pendências
Demand/ConvertDemand (F2.4), TimeEntry; conteúdo real das 4 abas placeholder e lógica de counters (fases futuras). Migração de dados reais segue não autorizada.
### Riscos
Nenhum novo.
### Próximo passo
Autorização para F2.4 (Demand + ConvertDemand).

## 2026-06-16 — [Fase 2 · F2.2] Project — CONCLUÍDA
### Resumo
Segundo recorte do domínio: `Project` (WD-03), do zero em Rails/Hotwire, conforme docs oficiais. PK uuid; top-level `resources :projects` (sidebar "Projetos" deixa de ser placeholder). Task/Demand/TimeEntry/ConvertDemand seguem fora do recorte.
### Features entregues
WD-03 Projetos: CRUD; `belongs_to :client` (FK on_delete cascade) + `Client has_many :projects, dependent: :destroy`; campos name/description/start_date/end_date/status (default `planning`)/budget (string, paridade); validação `end_date >= start_date` (model).
### Alterações realizadas (repo app/, commit 8a5e6fa)
Migration create_projects; model Project (+ `attribute :status default planning`); ajuste em Client (has_many :projects); policy ProjectPolicy (ADR-014); ProjectsController; rota `resources :projects` (substitui placeholder); views ERB (com `collection_select` de cliente).
### Testes/validações
`bin/rails test`: 59 runs, 167 assertions, 0 falhas/erros. rubocop 0 ofensas; brakeman 0 avisos; bundler-audit 0 vulnerabilidades. Cobertura: model (name/client/status default/ordem de datas/cascade), policy (autenticado/anônimo/scope), CRUD completo, visual-funcional via `assert_select` (lista, formulário com select de cliente, erro de validação, detalhe).
### Pendências
Task/Demand/TimeEntry/ConvertDemand (F2.3). Migração de dados reais segue não autorizada.
### Riscos
Nenhum novo.
### Próximo passo
Autorização para F2.3.

## 2026-06-16 — [Fase 2 · F2.1] Client + Contact — CONCLUÍDA
### Resumo
Primeiro recorte do domínio de trabalho: `Client` (WD-01) e `Contact` (WD-02), do zero em Rails/Hotwire, conforme docs oficiais. PK uuid (paridade RepoA / "preservar UUIDs"). Project adiado para F2.2.
### Features entregues
WD-01 Clientes (CRUD + `workspace_paths` text[] + GIN; `cnpj` nullable + partial-unique WHERE cnpj IS NOT NULL; normalização cnpj em branco → nil). WD-02 Contatos (CRUD aninhado; `has_many/belongs_to`; FK on_delete cascade).
### Alterações realizadas (repo app/, commit fd4a127)
Migrations create_clients/create_contacts; models Client/Contact; policies Pundit Client/Contact (ADR-014); controllers Clients/Contacts; rotas (resources clients + contacts aninhado); views ERB; ajuste em ApplicationController (filtros Pundit por lambda — evita ActionNotFound em controllers sem index); test_helper (Devise IntegrationHelpers).
### Testes/validações
`bin/rails test`: 41 runs, 112 assertions, 0 falhas/erros. rubocop 0 ofensas; brakeman 0 avisos; bundler-audit 0 vulnerabilidades. Cobertura: model (name, cnpj nullable/único, normalização, workspace_paths), policy (autenticado/anônimo/scope), CRUD clients e contacts, e visual-funcional via `assert_select` (lista, formulário, erro de validação, detalhe, contatos no contexto do cliente, navegação). Sem system/browser tests (não exigiu dependência pesada).
### Pendências
Project (F2.2), depois Task/Demand/TimeEntry/ConvertDemand. Migração de dados reais segue não autorizada.
### Riscos
Nenhum novo.
### Próximo passo
Autorização para F2.2 (Project).

## 2026-06-16 — [Operacional] Topologia de 2 repositórios + relocação da toolchain
### Resumo
Fechadas decisões operacionais: `app/` é repositório Git próprio (produto); a raiz é o repositório de planejamento/documentação. Mockup reafirmado como referência visual/funcional/de fluxo (não código-fonte, não insumo técnico reaproveitável).
### Alterações realizadas
- `app/.devstack/Dockerfile` criado (toolchain de dev movida para dentro do repo do app).
- `app/README.md` atualizado com o fluxo de build via Docker (`docker build -t omni-rails-dev .devstack`).
- Removida a cópia órfã `.devstack/Dockerfile` da raiz (pasta `.devstack/` apagada por ficar vazia).
- `docs/CONSTRAINTS.md` e `docs/PROJECT_STATUS.md` atualizados com a topologia de repositórios.
### Validações
`_origem/` e `_mockup/` intocados. Fase 2 não iniciada.
### Próximo passo
Commits separados (app/ e raiz); depois, autorização para a Fase 2.

## 2026-06-16 — [Fase 1] Rails Foundation (M1) — CONCLUÍDA
### Resumo
Fundação Rails 8.1.3 criada em `app/` via Docker (sem instalar runtime no host). Autenticação, autorização, jobs, rate-limit, CSRF, shell de UI, credentials, logging filtrado e CI configurados e verificados. Nenhuma entidade de domínio além de `users`. `_origem/` e pipeline Python intocados.
### Features entregues
WD-08 (Usuários/Devise), WD-09 (Permissões/Pundit), OP-04 (Logging filtrado), OP-09 (CI). Infra de jobs (Solid Queue) e rate-limit (rack-attack) operacionais.
### Alterações realizadas
Novo diretório `app/` (projeto Rails próprio) + `.devstack/Dockerfile` (imagem dev). Nenhuma alteração em `_origem/`. Em `docs/`, apenas governança (este log + ROADMAP/FEATURE_MATRIX/PROJECT_STATUS).
### Testes/validações
`bin/rails test`: 15 runs, 30 assertions, 0 falhas/erros. CI local: rubocop (41 arquivos, 0 ofensas), brakeman (0 avisos), bundler-audit (0 vulnerabilidades), importmap audit (0). Solid Queue verificado ponta a ponta (enqueue → worker → finished=1).
### Evidências
- Auth: não-autenticado → redirect login; login válido → dashboard 200.
- Authz: UserPolicy (admin vê todos; comum só a si).
- CSRF nativo: POST sem token → 422.
- Rate-limit: 6ª tentativa de login → 429.
- Devise bcrypt custo 10 + re-hash oportunístico (ADR-003).
### Pendências
Versionamento de `app/` (repo próprio vs incluir no planejamento) a decidir. Deploy real fica para a F7.
### Riscos
Nenhum novo. Pré-requisitos da F3 seguem pendentes (corpus, shard, schema_version).
### Próximo passo
Autorização explícita para iniciar a Fase 2 (migração do domínio de trabalho).

## 2026-06-16 — [Fase 0] Materialização da documentação de governança
### Resumo
Documentação oficial da Fase 0 materializada como arquivos reais em `docs/`. Nenhum código, projeto Rails, migration ou import. Pipeline Python intocado.
### Features entregues
Nenhuma de software. Documentação de governança (GOV-00 a GOV-04 aprovadas; GOV-05 definida/pendente).
### Alterações realizadas
Criados: `docs/ROADMAP.md`, `docs/MIGRATION_PLAN.md`, `docs/FEATURE_MATRIX.md`, `docs/DELIVERY_LOG.md`, `docs/ARCHITECTURE_DECISIONS_INDEX.md`, `docs/PROJECT_STATUS.md`, `docs/adr/ADR-001..ADR-017`.
### Testes/validações
N/A (documentação).
### Evidências
17 ADRs em status Aceito; M0 concluído; índice e matriz consolidados.
### Pendências
Pré-requisitos da Fase 3 (corpus, validação shard, schema_version) e ação de segurança SEC-DUMP.
### Riscos
Parser sem testes (até corpus); volume 240 MB; dump versionado (até SEC-DUMP).
### Próximo passo
Iniciar Fase 1 mediante autorização explícita. Não iniciar sem o comando.

## 2026-06-16 — [Fase 0] Fechamento e baseline aprovado
### Resumo
Fase 0 concluída. Decisões arquiteturais aprovadas e congeladas como baseline.
### Features entregues
Nenhuma (software não iniciado).
### Alterações realizadas
Nenhum arquivo (consolidação em texto, antes da materialização).
### Testes/validações
N/A.
### Evidências
ADRs 001–017 aceitos (2026-06-16); 9 decisões abertas confirmadas; M0 concluído.
### Pendências
Ver listas finais (pendências da Fase 1 e bloqueios da Fase 3).
### Riscos
Parser sem testes; volume; dump versionado.
### Próximo passo
Materializar documentação e iniciar Fase 1 mediante autorização.

## 2026-06-16 — [Fase 0] Diagnóstico técnico + Pacote de Decisão
### Resumo
Levantamento completo dos dois repositórios + mockup e pacote de decisão (ADRs, escopo, modelo, DDL, import, corpus, riscos). Sem software. Sem arquivos alterados.

## Template de entrada
(Copiar o bloco abaixo para o topo da seção "Entradas" a cada nova entrega.)

## YYYY-MM-DD — [Fase X] Nome da entrega
### Resumo
Descreva em poucas linhas o que foi entregue.
### Features entregues
Liste as features (com ID da FEATURE_MATRIX).
### Alterações realizadas
Documentos/módulos/arquivos afetados.
### Testes/validações
Testes executados e validações realizadas.
### Evidências
Contagens, comandos, logs, critérios comprovados.
### Pendências
O que ficou aberto.
### Riscos
Riscos remanescentes ou novos.
### Próximo passo
Próxima ação recomendada.
