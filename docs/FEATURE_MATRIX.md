# Omni — Matriz de Features

> **Baseline 2026-06-16.** Status: Não iniciado · Em análise · Em desenvolvimento · Em validação · Entregue · Bloqueado · Fora de escopo · Pronta p/ iniciar.
> **Governança aprovada.** WD-01 a WD-07 entregues nos recortes F2.1–F2.5 (Client/Contact, Project, Task base + `/tasks/:id`, Demand + ConvertDemand, **TimeEntry**) — **domínio CRUD completo; M2 concluído (2026-06-17)**. **Migração de dados reais de domínio = N/A**: o RepoA estava **inativo** e o snapshot real (DB `app_v2`) tem o **domínio vazio** (clients/contacts/projects/tasks/demands/time_entries = 0; só 2 usuários de teste, **não migrados**) — não há import histórico de domínio. Demais features conforme o status na tabela.
> **F2.UI (2026-06-17):** aplicado um **baseline visual hi-fi provisório** sobre as telas já existentes — **não cria features novas** e **não é a UI final** (a UI unificada real é a Fase 5). Ver [DELIVERY_LOG.md](DELIVERY_LOG.md).

## Governança / Fase 0 (documentação e decisão)

| ID | Item | Tipo | Status |
|---|---|---|---|
| GOV-00 | Diagnóstico técnico | Documentação | ✅ Entregue (aprovado) |
| GOV-01 | ADRs 001–021 (todos Aceito; ver [ARCHITECTURE_DECISIONS_INDEX.md](ARCHITECTURE_DECISIONS_INDEX.md)) | Decisão | ✅ Aprovado |
| GOV-02 | Modelo de dados + DDL de revisão | Documentação | ✅ Aprovado (planejado, não executado) |
| GOV-03 | Estratégia de import | Documentação | ✅ Aprovado |
| GOV-04 | 6 documentos de controle | Documentação | ✅ Aprovado (baseline) |
| GOV-05 | Corpus de caracterização | Documentação/plano | ✅ Entregue (corpus sintético em `test/fixtures/normalized_corpus/`; usado nos testes de import/turnos) |
| GOV-06 | Fronteiras do projeto documentadas | Documentação | ✅ Aprovado |

## Domínio de trabalho

| ID | Feature | Origem | Fase | Prioridade | Status | Dependências | Critério de aceite |
|---|---|---|---|---|---|---|---|
| WD-01 | Clientes (+workspace_paths, cnpj nullable) | Repo A/Mockup | 2 | MVP | ✅ Entregue (F2.1 — base CRUD). 🟡 **Lacuna operacional (PB-001):** lista `/clients` sem busca/filtro status/paginação (controller só `order(:name)`); buscar CNPJ externo = decisão | M1 | CRUD + partial-unique cnpj + GIN |
| WD-02 | Contatos | Repo A | 2 | MVP | ✅ Entregue (F2.1) — modelo: geridos na tela **Clientes** (lista/paginação/filtro por cliente; `is_primary`) | WD-01 | CRUD + FK cascade |
| WD-03 | Projetos | Repo A | 2 | MVP | ✅ Entregue (F2.2 — base CRUD). 🟡 **Lacuna operacional (PB-001):** lista sem busca/filtro cliente-status/paginação; período (início/fim/prazo), orçamento e duplicar = decisão pendente | WD-01 | CRUD + FK |
| WD-04 | Tarefas (+counters, página /tasks/:id) | Repo A/Mockup | 2 | MVP | ✅ Entregue (F2.3 base CRUD + /tasks/:id com apontamentos/conversas + badges). 🟡 **Lacuna operacional P0 (PB-001):** lista `/tasks` sem busca/filtro status-cliente/paginação (model tinha); código legível adiado (ADR-016) | WD-01,WD-03 | CRUD + abas + counters |
| WD-05 | Demandas | Repo A | 2 | MVP | ✅ Entregue (F2.4 — base CRUD; modelo cobre `origin`/`priority`/`observations`/status pending→converted). 🟡 **Lacuna operacional (PB-001):** lista `/demands` sem busca/filtro prioridade/paginação; sem cards/badge de origem (model tinha) | WD-01 | CRUD + filtros |
| WD-06 | Conversão demanda→tarefa (transacional) | Repo A | 2 | MVP | ✅ Entregue (F2.4 — `convert` atômico/testado). 🟡 (PB-001) botão "Converter" só no `demands/show` (model expunha na lista) — usabilidade menor | WD-04,WD-05 | Task+demand atômico |
| WD-07 | Apontamento de horas (+conversation_id) | Repo A/Mockup | 2 | MVP | ✅ Entregue (F2.5 — base CRUD + editar/excluir + total por tarefa). 🟠 **Lacuna funcional P0 (PB-001):** schema tem `is_running`/`start_time`/`end_time` mas **sem timer start/stop, sem cálculo de duração (manual), sem timesheet diário com totais, sem registro retroativo assistido**. Controle de tempo operacional ≠ completo | WD-04 | CRUD + soma duration |
| WD-08 | Usuários (migração Devise) | Repo A | 1 | MVP | ✅ Entregue (M1) | M0 ✅ | model User + Devise (custo bcrypt 10 + re-hash); migração de dados na F2 |
| WD-09 | Permissões (Pundit) | Mockup | 1 | MVP | ✅ Entregue (M1) | WD-08 | Pundit + verify_authorized; UserPolicy testada |
| WD-10 | Config/Health/Admin (tela Settings do modelo) | Repo A | — | P2 | **Runtime-switch produção/homologação + clone via HTTP/`spawn` = não migrar (ADR-015).** 🟡 (PB-001) **separar:** health/status de bases e painel admin **não** são descartados — avaliar como **OP (P1/P2)**; `/up` já existe (F7.1) | — | n/a |

> **Nota (TaskManager modelo, avaliado em `_origem/_repoa` — 2026-06-19):** app **React/Vite (client) + Express/Drizzle (server)** (referência, **não migra** o código; Omni reconstrói em Rails — ADR-001). **Telas** (`client/src/pages` + `App.tsx`): **Login** (gate `authApi.me`/CSRF/logout) → WD-08/WD-09; **Dashboard** (Health DB + URL da API + total de clientes) → **UI-01** (seção UI, não iniciado no Omni); **Clientes** (CRUD + filtro por status + paginação; **Contatos** geridos nesta tela) → WD-01/WD-02; **Projetos** (CRUD + filtro por cliente) → WD-03; **Tarefas** (lista + busca + filtro status/cliente + paginação 10/25/50/100 + CRUD modal + **detalhe com apontamentos** `TaskDetailDialog`) → WD-04/WD-07; **Demandas** (lista cards + busca + filtro prioridade + CRUD + **Converter→tarefa**) → WD-05/WD-06; **Configurações** (`environmentAdmin`) → **WD-10 não migrar (ADR-015)**. Badges de status/tipo/prioridade e confirmação de exclusão **já** no Omni. **Sem lacuna de *modelo/domínio*** (WD-01..09 cobrem as entidades; dados de domínio = **N/A**, snapshot `app_v2` vazio) — **porém a auditoria [PB-001](PB-001_PARITY_AUDIT.md) confirmou lacunas *operacionais*** não cobertas pelo "CRUD entregue": **busca/filtros/paginação ausentes nas 4 listas** (`/tasks`,`/clients`,`/projects`,`/demands` só fazem `order`) e **controle de tempo sem timer/timesheet** (WD-07). "Base CRUD entregue" ≠ "uso operacional completo". Auth/CSRF/rate-limit/CI = suporte → GOV/OP/SEC.

## Conversas

> **Nota (turnos lazy, pré-F5, 2026-06-17 · ADR-021):** a estratégia para localizar/abrir turnos sob demanda foi **decidida** no **[ADR-021](adr/ADR-021-lazy-load-turnos-via-indice-offsets.md)** (índice de offsets por `thread_id` em `sessions.jsonl`; ponteiros, não conteúdo; `seek`+`readline`; **sem importar turnos para o banco**). Isso destravou (ver status atual na tabela): **CV-02** (infra de índice/loader lazy entregue), **CV-05/CV-06** (parciais via F5.1 read-only), **CV-08** (entregue — `tool_input` em `<pre>`); **CV-07** (markdown sanitizado) **entregue na F5.2** (ADR-012). Fronteira em [`F5_CONTRACT_DECISIONS.md`](F5_CONTRACT_DECISIONS.md).
>
> **Nota (F3.0→F3.2.1, 2026-06-17 · commit `bd0a9ce`):** Sync de **metadados de conversa** entregue e publicado. F3.0 (contrato/corpus — ADR-018, `F3_CONTRACT_DECISIONS.md`); F3.1 (tabelas + `Sync::ImportSummaries` + rake `sync:summaries`, idempotente); **F3.2 = primeiro sync real controlado** de `summaries.jsonl` (1635 conversas; backup + allowlist `:ro`); **F3.2.1 = correção do merge** de escalares com `last_ts` nulo (`source_nil` 1069→0, `workspace_hash_nil`=13, `title_nil`=1067 por limitação do dado). **Turnos (`sessions.jsonl`/shards), UI, vínculo conversa↔tarefa e triagem ficam FORA** (ADR-018; F4/F5).
>
> **Nota (P0 readiness, 2026-06-18):** **M3 = MVP de metadados CONCLUÍDO** (sync real idempotente + folders + índice de turnos/loader lazy). Pendências do "módulo completo de conversas" movidas para roadmap: **OP-01** (sync manual via UI), **OP-03** (histórico de sync na UI), **CV-03** (títulos de sessão), **CV-10** (tags). **M4 = MVP manual CONCLUÍDO** (LK-01/02/03/07/08); LK-04/05/06 + `time_entry_id` = v1. **Fase 5 = MVP interno CONCLUÍDO (2026-06-19)** — F5.1 render + F5.1.5 PII + F5.2 markdown + F5.3 criar tarefa + F5.4 lista acionável + F5.5 navegação por âncoras; pendências (UI-01/04/09, CV-03/05/06/10, scorer, inbox) = roadmap/v1. Suíte: **274 runs/1068 assertions/0**. Deploy/produção (F7) **em progresso** — **F7.1 (2026-06-19)**: `production.rb` endurecido por ENV (TLS/hosts/mailer) + admin seed opt-in/idempotente; suíte **279/1087/0**. Restante (Solid cache/cable, Kamal, worker, `/normalized` prod, runbook) — ver "Readiness de produção" no PROJECT_STATUS e [`F7_CONTRACT_DECISIONS.md`](F7_CONTRACT_DECISIONS.md).

| ID | Feature | Origem | Fase | Prioridade | Status | Dependências | Critério de aceite |
|---|---|---|---|---|---|---|---|
| CV-01 | Import `summaries.jsonl` | Repo B/Mockup | 3 | MVP | ✅ Entregue (F3.2 — sync real idempotente; 1635 conversas) | M2 + corpus + validação shard | linhas válidas == count |
| CV-02 | Import `sessions.jsonl` (turnos, lazy) | Repo B | 3/5 | MVP | 🟡 Infra entregue (pré-F5: índice offsets + loader lazy; ADR-021) | CV-01 | turnos == turn_count |
| CV-03 | Títulos de sessão | Repo B | 3 | MVP | Não iniciado | CV-01 | títulos esperados |
| CV-04 | Lista de conversas | Mockup/Viewer | 5 | MVP | ✅ Entregue (F5.4 — lista acionável: status de vínculo + filtro `link`; F3.UI.1 base) | CV-01 | filtros funcionam |
| CV-05 | Detalhe de conversa | Mockup/Viewer | 5 | MVP | 🟡 Parcial (F5.1 read-only; F5.1.1 fix artefato + cor de role; F5.1.5 redação de PII; F5.2 markdown sanitizado) | CV-02 | render ordenado |
| CV-06 | Turnos ordenados (`seq`) | Repo B | 3/5 | MVP | 🟡 Parcial (F5.1 — ordenado por `line_no`) | CV-02 | UNIQUE(conv,seq) |
| CV-07 | Markdown sanitizado | Mockup | 5 | MVP | ✅ Entregue (F5.2 — `MarkdownRenderer`: commonmarker seguro + allowlist + links; XSS neutralizado) | CV-05 | payload XSS neutralizado |
| CV-08 | Tool calls (tool_input escapado) | Repo B/Mockup | 5 | MVP | ✅ Entregue (F5.1 — `tool_input` em `<pre>` escapado) | CV-05 | tool_input nunca HTML |
| CV-09 | Arquivos alterados | Repo B | 5 | v1 | Não iniciado | CV-05 | lista correta |
| CV-10 | Tags (conversa/workspace) | Repo B/Mockup/Viewer | 3/5 | MVP→roadmap | Não iniciado (modelo Viewer: `tags.json`; tags por `workspace_hash` herdadas pelas sessões; CRUD em `tab_tags`; filtro por tag na sidebar) | CV-01 | filtro por tag |
| CV-11 | Resolução de workspaces (`folder`) | Repo B | 3 | MVP | ✅ Entregue (F3.3 — `ResolveWorkspaceFolders`; órfãos 86→3; usuário `<USER>`; ADR-020) | CV-01 | `folder` resolvido; PII redigida |
| CV-12 | Busca full-text em conversas/turnos | Viewer/Repo B | 5/6 | v1 | Não iniciado (Viewer: `_search_text` = título+thread+texto+tags; sidebar `search`). Omni tem só `q` em título/thread_id | CV-05 | termo acha no conteúdo |
| CV-13 | Filtro por fonte + badge de origem | Viewer/Repo B | 5 | v1 | 🟡 Parcial (Omni: filtro `source` na lista; Viewer: multiselect de fontes + `_source_badge` colorido por origem) | CV-04 | filtra por fonte; badge por origem |
| CV-14 | Exportação de conversa (JSON v1.0 / ZIP / salvar no workspace) | Viewer | 6 | v1 | Não iniciado (Viewer: `build_session_json` schema v1.0 + `tab_export` ZIP em lote + salvar em `_chatsession`) | CV-05 | export determinístico (uuid5) |
| CV-15 | Timeline diária (mensagens do dia, cross-sessão) | Viewer | 6 | v1 | Não iniciado (Viewer: `tab_timeline` por data c/ navegação ◀▶). Distinta do diário UI-06 (lista de sessões/dia) | CV-02 | mensagens do dia agregadas |
| CV-16 | Telemetria de edição (`chat_editing_state`) | Viewer/Repo B | 6 | v1 | Não iniciado (Viewer: `_render_edit_event` — checkpoint/operation/snapshot por `requestId`/`model_id`/`agent_id`) | CV-05 | eventos de edição visíveis |

> **Nota (Viewer modelo, avaliado em `_origem/_repob/pipeline/viewer/app.py` — 2026-06-19):** o Viewer é um app **Streamlit** (referência, **não migra**; Omni reconstrói a UI lendo `output/normalized/`). Telas/`views` (radio `active_view`): **Conversa** (`tab_conversa` → header + stat-bar + render de turnos user/assistant/tool com markdown, janela "últimos N", "copiar texto", export JSON) → CV-05/CV-07/CV-08/CV-14; **Diário** (`tab_diario`, sessões por dia + busca/datas) → UI-06; **Timeline** (`tab_timeline`) → CV-15; **Workspaces** (`tab_workspaces`, cards/lista + tags) → CV-11/CV-10; **Tags** (`tab_tags`, CRUD) → CV-10; **Exportar** (`tab_export`, ZIP em lote) → CV-14. **Sidebar:** busca full-text (CV-12), filtro por fonte + badge (CV-13), filtro por tag (CV-10), "ocultar vazias", seletor de sessão, **recarregar dados** e **rodar pipeline** (`run_pipeline.py` → OP-01/OP-02), idioma (i18n) e tema claro/escuro. Itens de conforto do Viewer (i18n/tema/copiar/janela) = **não migrar/baixa prioridade**, salvo decisão futura.

## Vínculos

| ID | Feature | Origem | Fase | Prioridade | Status | Dependências | Critério de aceite |
|---|---|---|---|---|---|---|---|
| LK-01 | Vincular conversa↔tarefa | Mockup | 4 | MVP | ✅ Entregue (F4 MVP) | CV-01,WD-04 | link transacional |
| LK-02 | Vínculo primário (exclusivo) | Mockup | 4 | MVP | ✅ Entregue (F4 MVP — partial-unique) | LK-01 | partial-unique ≤1 |
| LK-03 | Vínculo por menção | Mockup | 4 | MVP | ✅ Entregue (F4 MVP — não conta) | LK-01 | não conta em contadores |
| LK-04 | Auto-link (≥0.85) | Mockup | 4 | v1 | Não iniciado (v1) | LK-02, CV-11 | auditado/reversível |
| LK-05 | Sugestões de vínculo (scorer) | Mockup | 4 | v1 | Não iniciado (v1) | CV-01,WD-04 | faixas 0.55/0.85 |
| LK-06 | Aceitar sugestão (lote) | Mockup | 6 | v1 | Não iniciado | LK-05 | lote atômico/item |
| LK-07 | Desfazer vínculo | Mockup | 4/5 | MVP | ✅ Entregue (F4 MVP — undo + counter) | LK-01 | reversível + counter |
| LK-08 | Auditoria de vínculo | Mockup | 4 | MVP | ✅ Entregue (F4 MVP — origin/created_by) | LK-01 | log origin/created_by |

## UI unificada

> **Nota (F2.UI, 2026-06-17):** as telas existentes receberam um **baseline visual hi-fi provisório** (shell/sidebar/topbar, dashboard com callout+cards, listas, detalhes, formulários, `/tasks/:id` com abas placeholder). Isso é apenas apresentação: **UI-01..UI-11 permanecem como Fase 5 (UI unificada real)** e seguem com o status abaixo. Sem conversas/sync/scorer/triage/TimeEntry/import.
> **Nota (F3.UI.1, 2026-06-17):** adicionado um **console read-only de validação da Fase 3** (`/conversations`, `/sync_runs` — só metadados, paginado). **Não é a UI-04/CV-05 da Fase 5**: não renderiza turnos/markdown, não lê `sessions.jsonl`/shards, não cria vínculo conversa↔tarefa, não executa sync e não altera dados. As features CV-*/UI-* da Fase 5 seguem com o status abaixo.

| ID | Feature | Origem | Fase | Prioridade | Status | Dependências | Critério de aceite |
|---|---|---|---|---|---|---|---|
| UI-01 | Dashboard | Mockup/Repo A | 5 | MVP | Não iniciado | WD-04,CV-01 | zonas renderizam |
| UI-02 | Lista de tarefas | Repo A | 2 | MVP | 🟡 Base entregue (`/tasks`, WD-04/F2); UI **unificada final** = F5 | WD-04 | paridade Repo A |
| UI-03 | Página `/tasks/:id` | Mockup | 2/5 | MVP | 🟡 Base entregue (F2.3 abas + aba "Conversas" F4); F5.5 navegação por âncoras (sem JS) + contagem; abas dinâmicas JS = opcional/roadmap | WD-04 | abas navegáveis |
| UI-04 | Aba Conversas | Mockup | 5 | MVP | Não iniciado | LK-01 | lista por kind |
| UI-05 | Inbox de triagem | Mockup | 6 | v1 | Não iniciado | LK-05 | lote + atalhos |
| UI-06 | Diário (view sob demanda) | Mockup/Viewer | 6 | v1 | Não iniciado | LK-01 | `?day=` mix |
| UI-07 | Settings de sync | Mockup | 6 | v1 | Não iniciado | OP-03 | parcial/erro visíveis |
| UI-08 | Workspaces órfãos | Mockup | 6 | v1 | Não iniciado | CV-11 | órfão listável |
| UI-09 | Modal de vínculo (Ctrl+L) | Mockup | 5 | MVP | Não iniciado | LK-01 | Turbo modal |
| UI-10 | Criar tarefa de conversa | Mockup | 5 | MVP | ✅ Entregue (F5.3 — `ConversationTasksController`: cria Task + link primary/manual em transação) | LK-01 | transação testada |
| UI-11 | Handoff IA externa | Mockup | 6 | v1 | Não iniciado | UI-03 | contexto correto |

## Operação

| ID | Feature | Origem | Fase | Prioridade | Status | Dependências | Critério de aceite |
|---|---|---|---|---|---|---|---|
| OP-01 | Sync manual (lê normalized) | Mockup | 3 | MVP→roadmap | Não iniciado (roadmap pós-MVP F3; hoje sync via rake `sync:summaries`/`sync:turn_refs`) | CV-01 | lê sem disparar pipeline |
| OP-02 | Sync agendado (agendador externo) | Mockup | 6 | v1 | Não iniciado | OP-01 | agenda dispara + Rails lê |
| OP-03 | Histórico de sync | Mockup | 3 | MVP→roadmap | Não iniciado (roadmap; `sync_runs`/`sync_run_items` gravados; UI de histórico pendente) | CV-01 | parcial/erro registrados |
| OP-04 | Logs (redação de conteúdo) | Repo A/Novo | 1 | MVP | ✅ Entregue (M1) | M1 | filter_parameter_logging (passw/secret/token/email/…) |
| OP-05 | Retenção (>30d) | Mockup | 6 | v1 | Não iniciado | CV-01 | vinculadas preservadas |
| OP-06 | Backup (pg_dump pré-carga) | Novo | 2/7 | MVP | 🟡 Parcial (`pg_dump` manual usado pré-carga em F3.2/F4/F5/F5.1.4; automação + backup de produção = F7) | M1 | backup antes de import |
| OP-07 | Rollback | Novo | 7 | MVP | Não iniciado | OP-06 | reverter validado |
| OP-08 | Testes + corpus | Novo | 1–7 | MVP | 🟡 Em andamento (suíte verde 225/811/0; corpus sintético em `test/fixtures/normalized_corpus`; sem SimpleCov) | M0 | suíte verde |
| OP-09 | CI | Repo A/Novo | 1 | MVP | ✅ Entregue (M1) | M1 | 4 jobs (scan_ruby/scan_js/lint/test) verdes localmente |
| SEC-DUMP | Remover snapshot/dump do VCS + gitignore | Segurança | 1 | MVP | ✅ Entregue | — | planejamento protegido via .gitignore; RepoA = referência/leitura |
