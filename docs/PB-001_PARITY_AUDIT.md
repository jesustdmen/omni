# PB-001 — Auditoria de paridade operacional (TaskManager → Omni)

> **Tipo:** auditoria de produto (read-only). **Não autoriza execução.** Itens executáveis vão ao `PRODUCT_BACKLOG.md` sob autorização do Product Owner.
> **Data:** 2026-06-19 · **HEAD:** `32d977f` · **Sem código/schema alterado.**
> **Pergunta central:** *o Omni, no estado atual, permite executar o dia a dia operacional que o TaskManager cobria?*

## 1. Resumo executivo

**Resposta curta:** **parcialmente.** O Omni tem **paridade de domínio (CRUD + modelo de dados)** e o **loop conversa↔tarefa** (F4/F5), mas **não tem ainda a camada operacional de uso diário** que o TaskManager entregava nas mesmas telas. Dois gaps dominam:

1. **Controle de tempo (P0, maior gap):** o schema de `time_entries` tem `is_running`/`start_time`/`end_time`, mas **não há timer (start/stop), nem cálculo de duração a partir de start/end, nem timesheet por dia com totais**. Hoje é CRUD manual de apontamento. O modelo oferecia registro fluido (timer + retroativo + histórico + totais).
2. **Listas sem operação (P0/P1):** as **4 listas de domínio** (`/tasks`, `/clients`, `/projects`, `/demands`) **não têm busca, filtros nem paginação** — os controllers só fazem `order` e carregam tudo. O modelo tinha busca + filtros (status/cliente/prioridade) + paginação (10/25/50/100) em **todas** as listas. Com volume real, a operação diária degrada.

O **resto está bem**: CRUD de clientes/contatos/projetos/tarefas/demandas, conversão demanda→tarefa (transacional), detalhe de tarefa com apontamentos e conversas vinculadas, criar tarefa da conversa. Decisões arquiteturais (ADR-015/016) descartam corretamente runtime-switch/clone e campos avançados de Task (reavaliar só o que virou necessário ao dia a dia).

**Recomendação de rota:** confirmar PB-003 (tempo) e a camada de **busca/filtros/paginação** das listas como os primeiros recortes P0, antes de retomar F7.2.

## 2. Estado inicial verificado

- Repo `app/`, branch `main`, **HEAD = `32d977f` = `origin/main`**, working tree **limpo**.
- ADRs relevantes lidos: **ADR-001** (Rails monólito + Hotwire), **ADR-002** (sem React no MVP; render/CmdK em Stimulus+Turbo), **ADR-015** (dropar runtime-switch; ambientes separados; sem clone de DB por HTTP), **ADR-016** (Task MVP = paridade + counters; adiados p/ v1: tags, assignee, due_date, estimated_hours, checklist, código legível).
- Modelo TaskManager (`_origem/_repoa`) avaliado **somente leitura**: client React/Vite (`pages/{Login,Dashboard,Clients,Projects,Tasks,Demands,Settings}`) + server Express/Drizzle (controllers/routes/services para clients/contacts/projects/tasks/timeEntries/demands/auth/admin/health).
- Estado real do Omni inspecionado em controllers/views/schema (evidências por área abaixo).

## 3. Matriz por área

### 3.1 Clientes / Contatos
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto diário | Recomendação |
|---|---|---|---|---|---|---|
| CRUD cliente (razão social/fantasia/CNPJ/status/telefone/endereço) | `pages/Clients.tsx`; schema Omni `clients` (name/trade_name/cnpj/status/phone/address) | **Coberto** (WD-01; CRUD + partial-unique cnpj) | coberto | — | ok | manter |
| Contatos por cliente + contato principal | `contactsApi`; Omni `contacts` (`is_primary`); `clients/show` gere contatos (14 refs) | **Coberto** (WD-02) | coberto | — | ok | manter |
| Busca (razão social/fantasia/CNPJ) | `Clients.tsx` search | `clients_controller#index` = `order(:name)` **sem busca** | **Lacuna de usabilidade** | P0 | alta (muitos clientes) | adicionar busca |
| Filtro por status (ativo/inativo) | `statusFilter` | ausente na lista Omni | Lacuna de usabilidade | P1 | média | adicionar filtro |
| Paginação | `PaginationBar` (10/25/50/100) | ausente (carrega tudo) | Lacuna de usabilidade | P1 | média/alta em escala | adicionar paginação |
| Buscar CNPJ (serviço externo) | botão "Buscar" no modelo | inexistente | **Decisão pendente** | P1 | conforto | decidir fornecedor/escopo |

### 3.2 Projetos
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| CRUD projeto + FK cliente | `Projects.tsx`; Omni `projects` | **Coberto** (WD-03) | coberto | — | ok | manter |
| Busca + filtro por cliente/status | `Projects.tsx` | `projects_controller#index` = `order(:name)` **sem busca/filtro** | Lacuna de usabilidade | P1 | média | adicionar |
| Paginação | `PaginationBar` | ausente | Lacuna de usabilidade | P1 | média | adicionar |
| Início/fim/prazo, orçamento | telas do modelo | não confirmados no schema Omni | **Decisão pendente** | P1/P3 | depende do uso | decidir campos v1 |
| Duplicar/copiar projeto | ação do modelo | inexistente | Decisão pendente | P1 | conforto | decidir |

### 3.3 Tarefas
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| CRUD tarefa (título/desc/cliente/projeto/tipo/status) | `Tasks.tsx` | **Coberto** (WD-04) | coberto | — | ok | manter |
| Badges de status/tipo | `StatusBadge`/`TaskTypeBadge`; Omni `tasks/index` usa badges | **Coberto** | coberto | — | ok | manter |
| Detalhe `/tasks/:id` (status/cliente/projeto + apontamentos + conversas) | Omni `tasks/show` (abas/âncoras F5.5; painel apontamentos; conversas vinculadas) | **Coberto** (parcial rico) | coberto | — | ok | manter; revisar profundidade (PB-004) |
| Busca (título/desc/código) | `Tasks.tsx` search | `tasks_controller#index` = `order(created_at)` **sem busca** | **Lacuna de usabilidade** | P0 | alta | adicionar |
| Filtro status + filtro cliente | `Tasks.tsx` selects | ausentes na lista Omni | **Lacuna de usabilidade** | P0 | alta | adicionar |
| Paginação (10/25/50/100) | `PaginationBar` | ausente (carrega tudo) | **Lacuna de usabilidade** | P0 | alta em escala | adicionar |
| Código legível (TSK-XXXX) | `formatTaskCode` | **adiado** (ADR-016 v1) | Descartado por decisão (reavaliar) | P1 | referência rápida | decisão PO se volta ao MVP |

### 3.4 Controle de tempo
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| Timer iniciar/parar | `TaskDetailDialog` (modelo) | schema tem `is_running`/`start_time`/`end_time`, mas **TimeEntry só valida**; "nem cálculo automático a partir de start/end nesta fase"; **sem rota start/stop** | **Lacuna funcional** | P0 | **alta** (maior gap) | criar ação timer |
| Cálculo de duração a partir de start/end | — | manual (`duration` preenchido à mão) | Lacuna funcional | P0 | alta | calcular no stop |
| Registro retroativo | form do modelo | possível via CRUD manual | **Parcialmente coberto** | P0 | alta | melhorar UX |
| Histórico por tarefa | `/tasks/:id` painel apontamentos (read-only + total) | **Coberto** (parcial) | parcialmente coberto | P1 | média | manter |
| Agrupamento + totais por dia (timesheet) | modelo | `time_entries_controller#index` = lista por `start_time` **sem agrupar/totalizar por dia** | **Lacuna funcional** | P0 | alta (fechamento de horas) | criar timesheet diário |
| Editar/excluir apontamento | modelo | **Coberto** (CRUD `/time_entries`) | coberto | — | ok | manter |
| Vínculo apontamento↔conversa | `conversation_id` (coluna preparada, sem uso) | **Decisão pendente** | decisão pendente | P1 | potencial | decidir uso |

### 3.5 Demandas
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| CRUD demanda (origem/prioridade/cliente/observações) | `Demands.tsx`; Omni `demands` (origin/priority/observations) | **Coberto** (WD-05) | coberto | — | ok | manter |
| Busca + filtro por prioridade | `Demands.tsx` | `demands_controller#index` = `order(created_at)` **sem busca/filtro** | **Lacuna de usabilidade** | P0/P1 | alta (entrada de trabalho) | adicionar |
| Cards + badge de origem/prioridade | telas do modelo | lista Omni simples (sem cards/badges de origem) | Lacuna de usabilidade | P1 | média | avaliar |
| Paginação | `PaginationBar` | ausente | Lacuna de usabilidade | P1 | média | adicionar |

### 3.6 Conversão demanda → tarefa
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| Converter demanda em tarefa (atômico) | `demandsApi.convert` | **Coberto** (WD-06; `post :convert` member; transacional/testado) | coberto | — | ok | manter |
| Surface do botão "Converter" | modelo expõe na **lista** (cards) | Omni expõe só no **`demands/show`** (`button_to convert_demand_path`) | **Lacuna de usabilidade** (menor) | P1 | baixa/média | avaliar expor na lista |

### 3.7 Configurações / Health / Admin
| Recurso (modelo) | Evidência | Estado no Omni | Classe | Prio | Impacto | Recomendação |
|---|---|---|---|---|---|---|
| Runtime-switch produção/homologação | `Settings.tsx`/`environmentAdmin` | **Descartado** (ADR-015; WD-10 não migrar) | descartado por decisão | — | n/a | não migrar |
| Gerar homologação (clone via HTTP/spawn) | modelo | **Descartado** (ADR-015) | descartado por decisão | — | n/a | não migrar |
| Health / status de bases | modelo Settings; Omni tem `/up` (rails/health) + F7.1 | **Parcialmente coberto** (`/up`); sem painel admin | Decisão pendente | P2 | operação | decidir painel OP |
| Abas Usuários/Testes | modelo | inexistente | Decisão pendente | P2/P3 | admin futuro | decidir |

### 3.8 API / contratos (TaskManager → Rails)
| Item | Evidência | Estado no Omni | Classe | Prio | Recomendação |
|---|---|---|---|---|---|
| API interna React→Express (CRUD) | server Express do modelo | **Traduzida** para controllers/views resourceful Rails (ADR-001/002) | coberto (conceito) | — | manter; sem JSON geral |
| Ações especiais: **convert** | member route do modelo | **Coberto** (`post :convert`) | coberto | — | manter |
| Ações especiais: **timer**, **lookup CNPJ**, **duplicar projeto** | modelo | inexistentes como rota/ação Rails | **Lacuna funcional/decisão** | P0 (timer)/P1 | criar como ação Rails se forem produto |
| API JSON externa (consumidor externo) | nenhuma evidência no modelo (era API interna do React) | inexistente no Omni (só HTML/Hotwire) | **Decisão pendente** (confirmar que não há consumidor externo) | P0-decisão | confirmar com PO |
| Health/admin endpoints | `/up` existe | parcial (OP/F7) | parcialmente coberto | P2 | classificar em OP |

**Diferenciação (regra do prompt):** API interna React antiga → **traduzida p/ controller/view/Turbo Rails** (correto, ADR-001/002); ação de tela (convert) → **rota/controller Rails** (✓); **API externa real** → **não há evidência** (confirmar); runtime-switch/clone HTTP → **não migrar** (ADR-015); admin/health → **OP/Admin** (a decidir).

## 4. Lacunas P0 confirmadas
1. **Timer de tempo (start/stop) + cálculo de duração** — funcional, ausente (schema pronto). *(PB-003)*
2. **Timesheet diário (agrupamento + totais por dia)** — funcional, ausente. *(PB-003)*
3. **Busca + filtros (status/cliente) + paginação em `/tasks`** — usabilidade, ausente. *(PB-004 / cross-cutting)*
4. **Busca + filtro por prioridade + paginação em `/demands`** — usabilidade, ausente. *(PB-005)*
5. **Busca em `/clients`** — usabilidade, ausente. *(PB-006)*
6. **Decisão API/contratos** — confirmar que não há consumidor externo (senão vira contrato). *(PB-008)*

## 5. Lacunas P1 confirmadas
- Filtros/paginação em `/projects` e filtro status em `/clients`; paginação geral das listas. *(PB-006/PB-007)*
- Cards/badges de origem em demandas; expor "Converter" na lista. *(PB-005)*
- Campos de projeto (início/fim/prazo/orçamento) + duplicar projeto. *(PB-007)*
- Vínculo apontamento↔conversa (`conversation_id` já existe, sem uso). *(PB-003/PB-010)*
- Código legível de tarefa (ADR-016 adiou; reavaliar se vira necessário). *(decisão)*

## 6. Itens descartados por decisão arquitetural
- **Runtime-switch produção/homologação** e **clone de banco via endpoint HTTP/spawn** → **ADR-015** (WD-10 "não migrar").
- **SPA React / API JSON geral** sem consumidor → **ADR-001/002** (Rails/Hotwire; ilha React só v1+ e só p/ render de conversa).
- Campos avançados de Task (tags, assignee, due_date, estimated_hours, checklist) → **ADR-016** (v1) — reavaliar individualmente só se virarem P0.

## 7. Itens já cobertos pelo Omni
- CRUD: clientes (+cnpj/status/trade_name), contatos (+is_primary, na tela do cliente), projetos, tarefas (+badges), demandas (origin/priority/observations).
- **Conversão demanda→tarefa** transacional (`convert`).
- **Detalhe `/tasks/:id`** com apontamentos (read-only + total) e conversas vinculadas (navegação por âncoras F5.5).
- **Loop conversa↔tarefa** (F4/F5): lista acionável, render seguro (markdown+PII), criar tarefa da conversa, vínculo dos dois lados.
- CRUD de apontamentos (`/time_entries`) com editar/excluir.
- Auth (Devise/Pundit), CSRF, rate-limit, logs com redação, CI — suporte (GOV/OP/SEC).

## 8. Decisões pendentes para o Product Owner
1. **Timer obrigatório** ou **registro retroativo bem feito** já resolve? (define peso do PB-003).
2. **Buscar CNPJ**: serviço externo (qual?) ou só facilitar preenchimento local?
3. **Código legível de tarefa** (TSK-XXXX): volta ao MVP ou fica v1 (ADR-016)?
4. **Duplicar projeto** + campos período/orçamento: produto ou v1?
5. **API externa**: existe algum consumidor externo (automação/app)? Se não, não criar JSON geral.
6. **Health/admin**: painel OP útil localmente ou só produção (F7)?
7. **Busca em conteúdo de conversas** (CV-12): P1 agora ou v1?
8. **`conversation_id` em time_entries**: ativar vínculo apontamento↔conversa?

## 9. Recomendação de próximos PBs (ordem sugerida)
1. **PB-003 — Controle de tempo** (timer/stop+duração, timesheet diário com totais). *Maior valor diário.*
2. **Camada de listas operacionais** (busca + filtros + paginação) — atende PB-004 (tarefas), PB-005 (demandas), PB-006 (clientes). *Pode ser um recorte transversal ou por área.*
3. **PB-004 — Detalhe de tarefa** (profundidade do `/tasks/:id`).
4. **PB-008 — Decisão API/contratos** (confirmar ausência de consumidor externo; registrar).
5. **PB-007 / PB-009 / PB-010 / PB-012** — P1/P2 conforme decisões do PO.
6. **PB-011 — Retomar F7.2** só após o gate de produto (GP-01..07).

## 10. Impacto sugerido na FEATURE_MATRIX / PB-002
A `FEATURE_MATRIX` hoje marca WD-01..07 como "Entregue" no sentido **CRUD/domínio** — correto, mas **insuficiente como sinal operacional**. Sugestão para PB-002 (sob autorização, depois):
- Acrescentar coluna/nota distinguindo **"CRUD entregue"** de **"operacional para uso diário"**.
- Refletir como **parcial/lacuna** (não regressão): listas de domínio sem busca/filtro/paginação; controle de tempo sem timer/timesheet.
- Não rebaixar status entregues sem evidência; registrar as lacunas como itens novos (P0/P1) ligados aos PBs, sem marcar nada como "entregue" sem evidência.
- **Sem tocar `DELIVERY_LOG`** (não houve entrega de produto nesta auditoria).
