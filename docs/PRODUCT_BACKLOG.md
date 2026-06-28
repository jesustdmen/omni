# Omni — Product Backlog

> **Status inicial:** proposta de governança de produto para a nova onda pós-F7.1.  
> **Função:** fonte oficial para priorização e autorização de trabalho de produto.  
> **Regra central:** nenhum agente deve implementar item de produto que não esteja registrado aqui e autorizado explicitamente pelo Product Owner.

---

## 1. Propósito

Este documento registra o backlog oficial de produto do Omni, com foco em transformar a aplicação em uma ferramenta de uso diário para organizar clientes, projetos, tarefas, demandas, apontamentos de horas e conversas técnicas.

Ele complementa, mas não substitui:

- `FEATURE_MATRIX.md` — inventário/status granular de features.
- `ROADMAP.md` — fases e marcos macro.
- `PROJECT_STATUS.md` — fotografia consolidada do projeto.
- `DELIVERY_LOG.md` — histórico append-only de entregas reais.
- `PRODUCT_GAP_REVIEW.md` — diagnóstico de lacunas e decisões pendentes.

Este backlog deve ser usado para evitar perda de contexto, escopo implícito e execução baseada em inferência.

---

## 2. Regras anti-alucinação / anti-drift

1. **Não executar item não autorizado.** Um agente só pode implementar item com status `Pronto para execução` e autorização explícita do Product Owner.
2. **Não marcar como entregue sem evidência objetiva.** Entrega exige commit, diff, teste/validação e atualização dos documentos oficiais pertinentes.
3. **Não converter hipótese em fato.** Quando não houver evidência no código/docs/telas, registrar como `Decisão pendente` ou `A confirmar`.
4. **Não alterar `_origem/` nem `_mockup/`.** Eles são referência somente leitura.
5. **Não retomar F7 por inércia.** Readiness de produção fica pausada até passar pelo gate de produto operacional.
6. **Não recriar API JSON por reflexo.** Para cada endpoint legado, decidir se era API interna do React, ação de tela Rails, contrato externo, admin/health ou descarte.
7. **Não inflar o MVP.** Separar `P0 uso diário`, `P1 usabilidade forte`, `P2 produção/operação`, `P3 evolução`.
8. **Não usar a conversa como fonte de verdade permanente.** Decisões aprovadas devem virar documento em `app/docs/`.

---

## 3. Prioridades

| Prioridade | Definição | Exemplo |
|---|---|---|
| P0 | Necessário para uso diário da ferramenta | registrar tempo, abrir tarefa, converter demanda |
| P1 | Melhora forte de usabilidade ou paridade operacional relevante | duplicar projeto, buscar CNPJ, filtros melhores |
| P2 | Produção/operação técnica | Solid, deploy, backup, rollback, worker |
| P3 | Evolução futura / v1 | scorer, auto-link, inbox avançada, API externa |

---

## 4. Status permitidos

| Status | Significado |
|---|---|
| Proposto | Item identificado, ainda não validado como necessário |
| Em análise | Item em revisão de produto/técnica |
| Aprovado | Item aceito como parte do produto, mas ainda sem autorização de execução |
| Pronto para execução | Pode ser enviado ao agente executor mediante prompt específico |
| Em execução | **Agente atualmente autorizado trabalhando no item** |
| Parcialmente entregue | **Algumas fatias entregues (e aceitas) e outras ainda pendentes** |
| Entregue | Passou pelo **gate de integridade** abaixo (não basta commit/teste/doc isolado) |
| Descartado | Decisão explícita de não fazer |
| Bloqueado | Depende de decisão, dado, técnica ou outro item |

### Gate de integridade (para marcar "Entregue")

`Planejada → Implementada → Aceita pelo PO → Publicada → Documentada → Entregue`

- **Feature visível ao usuário:** "Entregue" exige **aceite manual explícito do PO** (além de implementação publicada + docs).
- **Entrega puramente técnica/docs** (sem UI visível): registrar **qual evidência substitui o teste manual** (ex.: teste automatizado verde + smoke + revisão), pois não há aceite visual.
- **Commit, testes OU documentação isoladamente NÃO bastam** para "Entregue".

---

## 5. Gate de produto antes de F7

A continuidade de F7.2+ fica pausada até que o Product Owner valide o seguinte gate:

| Gate | Critério |
|---|---|
| GP-01 | O Omni permite registrar e consultar trabalho diário sem depender do TaskManager antigo |
| GP-02 | Tarefa possui detalhe operacional suficiente para acompanhamento real |
| GP-03 | Apontamento de horas atende uso real: timer/retroativo/histórico/totalização/manutenção |
| GP-04 | Demandas podem ser registradas, priorizadas e convertidas em tarefa com clareza |
| GP-05 | Clientes, contatos e projetos têm busca/filtros/campos suficientes para operação |
| GP-06 | A decisão API TaskManager → Rails está documentada, sem lacunas de contrato externo |
| GP-07 | `FEATURE_MATRIX.md` reflete a revisão de produto aprovada |

Enquanto estes gates não forem aceitos, F7 permanece como P2.

---

## 6. Backlog inicial

### PB-001 — Auditoria de paridade operacional do TaskManager

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue** (auditoria em `docs/PB-001_PARITY_AUDIT.md`; commit `3037a00`) |
| Problema que resolve | Evita seguir implementação/produção sem saber se o Omni cobre o uso diário real observado nas telas do TaskManager. |
| Origem/evidência | Telas do TaskManager analisadas em sessão de produto; `FEATURE_MATRIX.md` atual está macro/CRUD demais. |
| Critério de aceite | ✅ `PB-001_PARITY_AUDIT.md` com matriz por área (8 áreas + API), impacto, prioridade e decisões pendentes. Lacunas P0 confirmadas: controle de tempo (timer/timesheet) e listas sem busca/filtro/paginação. |
| Fora de escopo | Implementar código; alterar schema; alterar `_origem`; atualizar `DELIVERY_LOG` como se fosse entrega de produto. |
| Dependências | Docs atuais; imagens/telas do TaskManager; código Omni; `_origem/_repoa` somente leitura. |
| Relacionado | `PRODUCT_GAP_REVIEW.md`, `FEATURE_MATRIX.md`, WD-01..WD-10. |

### PB-002 — Revisão oficial da FEATURE_MATRIX após auditoria

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue** (revisão aplicada na `FEATURE_MATRIX.md` após PB-001) |
| Problema que resolve | A matriz atual pode transmitir que “CRUD entregue” equivale a ferramenta operacional completa. |
| Origem/evidência | Discussão pós-commit `497cb49`; auditoria `PB-001_PARITY_AUDIT.md`. |
| Critério de aceite | ✅ Seção "Domínio de trabalho" da `FEATURE_MATRIX.md` revisada: WD-01/03/04/05 com **lacuna operacional** (busca/filtro/paginação) e WD-07 com **lacuna funcional P0** (timer/timesheet) registradas; WD-10 separa não-migrar (ADR-015) de health/admin (OP); nota "sem lacuna de modelo ≠ uso operacional completo". Sem rebaixar entregas com evidência; sem marcar lacuna como entregue. |
| Fora de escopo | Usar a matriz como rascunho de debate; marcar itens como entregues sem evidência. |
| Dependências | PB-001. |
| Relacionado | `FEATURE_MATRIX.md`, `PROJECT_STATUS.md`. |

### PB-003 — Controle de tempo operacional

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue** — **PB-003a** (`d11f099`), **PB-003b** (`5fcf125`) e **PB-003c** (`0f2bc9c`) **ENTREGUES, ACEITAS e PUBLICADAS** (aceite manual do PO + checks verdes). PB-003 **integralmente concluída**. |
| Problema que resolve | O uso diário depende de registrar tempo com fluidez, não apenas CRUD de `time_entries`. |
| Origem/evidência | Telas mostram timer, status parado, descrição do trabalho, registro retroativo, histórico por dia, duração e ações de manutenção. Contrato em `PB-003_TIME_CONTRACT.md`. |
| Critério de aceite | Usuário consegue iniciar/parar tempo, registrar retroativo, visualizar histórico por tarefa, ver totais por dia e editar/excluir apontamentos. |
| Fora de escopo | Relatórios financeiros avançados; faturamento; integração externa. |
| Dependências | WD-04, WD-07; validação do modelo atual de `time_entries`. |
| Relacionado | WD-07, UI-03. |

**Fatias:**

- **PB-003a — ENTREGUE (`d11f099`, 2026-06-19):** iniciar/parar timer; **cálculo automático de duração em segundos**; **paralelismo configurável** (`ALLOW_PARALLEL_RUNNING_TIMERS`, default `true`); **bloqueio de timer duplicado na mesma tarefa** (índice único parcial + validação); **histórico de apontamentos** operacional (título PT, contador, colunas Data/Descrição/Início/Término/Duração/Ações) com **ações inline** (ver/editar/excluir + parar) com ícones e cores. Aceite manual do PO no fluxo principal + paralelismo default. Modo `=false` coberto por teste automatizado.
- **PB-003b — ENTREGUE (`5fcf125`, 2026-06-20):** agrupamento de apontamentos **por data** (grupos em ordem decrescente; itens por horário decrescente), **subtotal diário** (exclui timers em andamento), total geral e ações inline preservados. Aceite manual do PO; checks verdes (295/1181/0; rubocop 135/0; brakeman 0).
- **PB-003c — ENTREGUE (`0f2bc9c`, 2026-06-20):** **registro retroativo assistido** (início + término → **duração derivada em segundos** no model; `date` derivada de `start_time`); **proteção do timer running** (`end_time` nil, `duration = 0`, edição genérica só altera descrição); **aviso global de timers** na topbar + **lista global** `/time_entries/running` (tarefa/cliente/início/tempo decorrido/abrir/parar, sem N+1); **nota de sobreposição** (totais = tempo lançado) e **ajuste visual final** do histórico (cabeçalho de data, subtotal alinhado, total geral no `tfoot`). Aceite manual do PO; checks verdes (métricas correntes: ver `PROJECT_STATUS.md`).

**PB-003 integralmente concluída** (a/b/c entregues, aceitas e publicadas). Escopos avançados — **timesheet/relatórios e faturamento** — permanecem **fora da PB-003** (futuro).

### PB-004 — Detalhe de tarefa utilizável no dia a dia

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue (concluída)** — **PB-004a** (lista operacional de `/tasks`), **PB-004b** (checklist persistente) e **PB-004c** (vínculo demanda↔tarefa) **ENTREGUES e ACEITAS** (2026-06-21). Decisão do PO: **PB-004 está funcionalmente concluída com as fatias a/b/c** — não haverá PB-004d genérica; melhorias pontuais futuras entram como itens próprios. |
| Problema que resolve | A tarefa precisa ser o centro operacional: detalhes, tempo, conversas, demanda/histórico e ações claras. |
| Origem/evidência | `/tasks/:id` já existe, mas a navegação por âncoras foi reconhecida como melhoria mínima; algumas abas/fluxos podem ainda estar pobres. |
| Critério de aceite | Página da tarefa permite acompanhar status/tipo/cliente/projeto, tempo, conversas vinculadas e ações principais sem ambiguidade. |
| Fora de escopo | Abas JS ricas se âncoras forem suficientes; campos v1 sem decisão. |
| Dependências | PB-003, LK-01/LK-02/LK-07. |
| Relacionado | WD-04, UI-03, UI-04, UI-10. |

**Fatias:**

- **PB-004a — ENTREGUE (2026-06-21):** lista operacional de `/tasks` — **busca** por título/descrição (case-insensitive; `%`/`_` escapados), **filtros** combináveis (status/tipo/cliente; inválidos ignorados), **paginação** (10/25/50/100, default 50; total antes de limit/offset; ordenação estável `created_at desc, id desc`; links preservam params; página inválida → 1), tabela (título+trecho, cliente, projeto, status, tipo, criada em, ações), **ações** ver/editar/excluir (confirmação) + "Nova tarefa", **estados vazios** (sem tarefas / sem resultado com "Limpar filtros"). `policy_scope`; `includes` sem N+1; sem migration/dependência. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).
- **PB-004b — ENTREGUE (2026-06-21):** **checklist persistente** na seção Detalhes de `/tasks/:id` — adicionar/marcar/desmarcar/editar/excluir (com confirmação), contador concluído/total, estado vazio; **edição in-place** da linha via `<details>` (sem JS; Turbo só melhoria progressiva). Model `ChecklistItem` (uuid; `task_id` FK **ON DELETE CASCADE**; `content` com trim/presence; `completed` default false; ordem `created_at, id`, sem `position`/`default_scope`); rotas aninhadas + Pundit (ADR-014); itens sempre escopados pela tarefa da URL; strong params só `content`/`completed`. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).
- **PB-004c — ENTREGUE (2026-06-21):** **vínculo opcional 1:1 demanda→tarefa de origem** (`tasks.demand_id` uuid null, FK **ON DELETE RESTRICT**, índice único parcial). Conversão (`ConvertDemand`) com **lock + revalidação pós-lock** cria a tarefa já vinculada (concorrência não gera 2ª tarefa). Serviço explícito **`DeleteTask`**: excluir a tarefa devolve a demanda a **pending** (limpa `converted_at`) em transação; demanda **vinculada não é excluível** (bloqueio amigável + FK RESTRICT). UI: aba **Demanda** funcional na tarefa (origem/estado vazio) + link p/ tarefa na demanda (sem nova conversão). Reconciliação dev: vínculo histórico `4549551a→8bcbbcb5` aplicado após validação. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).
- **PB-004d+ — PENDENTE:** demais melhorias do detalhe `/tasks/:id`, conforme priorização do PO.

### PB-005 — Demandas e conversão usável

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue** — lista operacional de `/demands` + aceite do PO (2026-06-21). |
| Problema que resolve | Demandas precisam servir como entrada rápida de trabalho e virar tarefa sem perda de contexto. |
| Origem/evidência | Telas mostram cards, busca, filtro por prioridade, origem, cliente, prioridade, data/hora e botão converter. |
| Critério de aceite | Usuário registra demanda, filtra por prioridade/origem, edita/exclui e converte em tarefa com transação clara. |
| Fora de escopo | Automação de triagem por IA; SLA; integrações externas. |
| Dependências | WD-05, WD-06, WD-04. |
| Relacionado | WD-05, WD-06. |

**Entregue (2026-06-21):** `/demands` operacional (mesmo padrão da PB-004a) — **busca** por título/descrição/observações (case-insensitive; `%`/`_` escapados); **filtros** combináveis prioridade/origem/status/cliente (allowlist; inválidos ignorados); **paginação** 10/25/50/100 (default 50; total antes de limit/offset; ordem estável `created_at desc, id desc`; links preservam params; página inválida → 1); tabela (título+trecho/cliente/origem/prioridade/status/criada em/ações); **conversão pela lista** quando pending+cliente (confirmação), **pending sem cliente** mostra "sem cliente" (não convertível), **converted** mostra "Abrir tarefa" (sem nova conversão); estados vazios (sem demandas / sem resultado com "Limpar filtros"). `includes(:client, :converted_task)` sem N+1; reutiliza `ConvertDemand` + vínculo 1:1 (PB-004c); sem migration/dependência. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).

> **Nota (busca global da topbar):** ~~placeholder "Buscar… (em breve)"~~ **ENTREGUE na PB-013a** (2026-06-21) — topbar agora é busca global funcional (`GET /search`).

### PB-006 — Clientes e contatos com busca e dados completos

| Campo | Valor |
|---|---|
| Prioridade | P0/P1 |
| Status | **Entregue** — listas operacionais Empresas/Contatos + cadastro via busca de CNPJ; aceite do PO (2026-06-21). |
| Problema que resolve | Clientes/contatos precisam ser práticos para consulta diária e relacionamento com tarefas/projetos/demandas. |
| Origem/evidência | Telas mostram abas Empresas/Contatos, busca por razão social/fantasia/CNPJ, filtro status, contatos por cliente e contato principal. |
| Critério de aceite | Usuário encontra cliente/contato rapidamente, mantém contato principal e filtra por cliente/status. Decisão explícita sobre busca de CNPJ. |
| Fora de escopo | Integração obrigatória com serviço externo de CNPJ sem decisão de fornecedor. |
| Dependências | WD-01, WD-02, ADR-017. |
| Relacionado | WD-01, WD-02. |

**Entregue (2026-06-21):** `/clients` com **abas server-side** (`tab=companies|contacts`). **Empresas:** busca razão social/nome fantasia/**CNPJ com ou sem pontuação** (`%`/`_` escapados); filtro status; paginação 10/25/50/100 (default 50; ordem `name asc, id asc`; params preservados; página inválida → 1); colunas nome/fantasia/CNPJ/telefone/status/**contato principal**/ações (ver/editar/excluir). **Contatos:** busca nome/e-mail/telefone/cargo; filtros cliente/status do cliente/principal; ações editar/excluir + link p/ cliente. **Contato principal:** índice único parcial `contacts(client_id) WHERE is_primary` + regra transacional (salvar principal desmarca o anterior do mesmo cliente; isola outros; concorrência barrada). **Cadastro via busca de CNPJ:** decisão do PO de **incluir** (a restrição original "sem CNPJ externo" foi revista) — autopreenche o form a partir da **BrasilAPI** via Stimulus (melhoria progressiva: sem JS, cadastro segue manual). Ver **ADR-022**. `policy_scope`; `includes` sem N+1; estados vazios + "Limpar filtros"; sem alterar/excluir dados dev. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).
> **Atualização (2026-06-23 — supersede a implementação original):** a consulta de CNPJ era feita por **proxy no Rails** (`GET /clients/cnpj_lookup` → `Cnpj::Lookup`). Esse proxy foi **removido** e a consulta **voltou ao navegador** (chamada direta à BrasilAPI, como no RepoA): o IP de saída do container era rate-limitado (HTTP 429) e travava o uso; do IP do usuário funciona. Hoje: **sem rota `cnpj_lookup`, sem `Cnpj::Lookup`**; o Stimulus chama a BrasilAPI (host fixo no cliente) e a **CSP permite `connect-src` para a BrasilAPI**. Fonte arquitetural: **ADR-022 (addendum 2026-06-23, status Revertida)**.

### PB-007 — Projetos com status, período, orçamento e duplicação

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **Entregue** — `/projects` operacional + duplicação; aceite do PO (2026-06-21). |
| Problema que resolve | Projetos precisam organizar tarefas por cliente, período, status e orçamento; duplicação acelera criação de projetos similares. |
| Origem/evidência | Telas mostram busca, filtro por cliente/status, início/fim, prazo, orçamento e ação duplicar/copiar. |
| Critério de aceite | Projeto possui campos/ações necessários ou decisão explícita do que fica para v1. Duplicação cria projeto novo sem copiar indevidamente dados sensíveis. |
| Fora de escopo | Gestão financeira completa do projeto; alocação de equipe; Gantt. |
| Dependências | WD-03. |
| Relacionado | WD-03. |

**Entregue (2026-06-21):** `/projects` operacional (mesmo padrão das demais listas) — busca por nome/descrição (`%`/`_` escapados); filtros cliente + status; paginação 10/25/50/100 (default 50; ordem `name asc, id asc`; params preservados; página inválida → 1); colunas Projeto(nome+trecho)/Cliente/Status/Período/Orçamento/Ações (ver/editar/**duplicar**/excluir). **Status fechado** em 4 valores (`planning`/`in_progress`/`completed`/`on_hold`) com **CHECK no banco** + **labels PT-BR** + **select no form** (substituiu campo livre). **Duplicação** (`DuplicateProject`, transacional): "Nome (cópia)" copiando só cliente/descrição; status → planning; **não** copia orçamento/datas/tarefas/vínculos; leva à edição; rollback em falha. `end_date` = prazo/fim (sem `due_date` novo); término ≥ início; orçamento informativo (sem cálculos). `policy_scope`; `includes(:client)` sem N+1; estados vazios + "Limpar filtros". Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`). **Com PB-004a/PB-005/PB-006/PB-007, as 4 listas operacionais (tarefas/demandas/clientes/projetos) estão completas — lacuna operacional da PB-001 fechada.**

### PB-008 — Revisão API/contratos TaskManager → Rails

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | Proposto |
| Problema que resolve | Evita confundir API interna React/Express com contrato externo obrigatório e evita perder ações reais que precisam existir em Rails. |
| Origem/evidência | TaskManager original era React/Vite + Express/Drizzle; Omni é Rails/Hotwire por ADR. |
| Critério de aceite | Tabela classificando endpoints/contratos como API interna React, ação Rails, API externa, admin/health, descartado ou lacuna. |
| Fora de escopo | Criar API JSON geral sem consumidor; reintroduzir React/SPA. |
| Dependências | ADR-001, ADR-002, MIGRATION_PLAN; inspeção read-only de `_origem/_repoa`. |
| Relacionado | GOV/OP/WD, `PRODUCT_GAP_REVIEW.md`. |

### PB-009 — Health/configurações/admin: decidir o que migra

| Campo | Valor |
|---|---|
| Prioridade | P1/P2 |
| Status | Proposto |
| Problema que resolve | A tela Settings do TaskManager mistura health/status útil com runtime-switch/homologação descartado por ADR-015. |
| Origem/evidência | Telas mostram ambiente ativo, health geral, status de bases, abas Ambiente/Usuários/Testes, produção/homologação. |
| Critério de aceite | Separar claramente: não migrar runtime-switch/clone HTTP; avaliar health/status/admin como OP/UI. |
| Fora de escopo | Endpoint HTTP de clone de banco; AsyncLocalStorage/Proxy de DB; spawn de pg_dump via web. |
| Dependências | ADR-015, F7_CONTRACT_DECISIONS. |
| Relacionado | WD-10, OP, UI-07. |

### PB-010 — Busca e recuperação de contexto

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | Proposto |
| Problema que resolve | O valor do Omni aumenta se o usuário recuperar contexto de conversas/tarefas/clientes rapidamente. |
| Origem/evidência | Viewer possui busca full-text em título/thread/texto/tags; Omni atual parece ter busca mais restrita. |
| Critério de aceite | Definir escopo de busca: título/thread, conteúdo de turnos, tags, fonte, cliente/projeto/tarefa, com limites de performance e segurança. |
| Fora de escopo | Search engine externa; embeddings; ranking sem necessidade medida. |
| Dependências | CV-05, CV-12, ADR-021. |
| Relacionado | CV-12, CV-13, CV-10. |

### PB-011 — Retomada controlada da F7 após gate de produto

| Campo | Valor |
|---|---|
| Prioridade | P2 |
| Status | Bloqueado |
| Problema que resolve | Garante que readiness de produção só avance quando o produto estiver suficientemente útil. |
| Origem/evidência | F7.1 entregue; F7.2 planejada, mas rota foi pausada por decisão de produto. |
| Critério de aceite | GP-01..GP-07 aceitos pelo Product Owner; F7.2 retomada com prompt específico. |
| Fora de escopo | Deploy real sem autorização; schema de produção sem gate. |
| Dependências | Gate de produto. |
| Relacionado | F7_CONTRACT_DECISIONS.md, PROJECT_STATUS.md. |

### PB-012 — Conversas/vínculos v1: UI rica, tags, títulos, scorer e inbox

| Campo | Valor |
|---|---|
| Prioridade | P1/P3 |
| Status | Proposto |
| Problema que resolve | Evolui o módulo de conversas além do MVP interno: classificação, triagem e vínculo assistido. |
| Origem/evidência | F5 concluiu o loop interno, mas UI-04/09, CV-03/10, scorer, inbox e auto-link ficaram roadmap/v1. |
| Critério de aceite | Separar o que é necessário para uso diário imediato do que é automação futura. |
| Fora de escopo | Auto-link silencioso; import massivo de turnos; conteúdo sem sanitização. |
| Dependências | F4/F5, ADR-012, ADR-013, ADR-021. |
| Relacionado | CV/LK/UI. |

### PB-013 — UX de navegação/contexto entre telas

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **CONCLUÍDA** — **PB-013a** (busca global) ENTREGUE (2026-06-21) + **PB-013b** (preservação de contexto/navegação) ENTREGUE com aceite do PO (2026-06-22). |
| Problema que resolve | A navegação entre telas ainda está estranha, com excesso de uso de "voltar" e perda de contexto operacional ao circular entre lista/detalhe/edição. |
| Origem/evidência | Observação do Product Owner durante o aceite manual da PB-003a (2026-06-19). |
| Critério de aceite | Retorno coerente entre lista↔detalhe↔edição preservando o contexto operacional (ex.: voltar para a tarefa após editar/excluir apontamento; menos "voltar" cego). |
| Fora de escopo | Redesenho amplo de navegação; SPA; breadcrumbs avançados sem necessidade. |
| Dependências | — |
| Relacionado | UI-03, WD-04, WD-07. |

**Fatias:**

- **PB-013a — ENTREGUE (2026-06-21):** **busca global** (`GET /search`) sobre os dados funcionais, agrupada por categoria (Tarefas/Demandas/Projetos/Clientes/Contatos/Conversas) com **badge de tipo**, **"Encontrado em: …"** e contexto; tarefas também por **checklist/apontamento** (DISTINCT, sem duplicar); conversas por título com **source/workspace** (sem turnos — ADR-021); top-5 por categoria + **"ver todos"**; cada resultado é um **card-link único** com **"Ir →"** (sem JS, foco por teclado, hover/focus, responsivo, aria contextual); **"← Voltar"** retorna à tela de origem (referer interno; fallback Dashboard). Topbar passou de placeholder a **form GET funcional**. Aceite do PO; checks verdes (ver `PROJECT_STATUS.md`).
- **PB-013b — ENTREGUE (2026-06-22):** **mecanismo central `return_to`** (concern `ReturnNavigation`) — sanitizador único que aceita só caminho interno (preserva query + fragmento) e rejeita scheme/host, `//host`, backslash, CR/LF, controle e tamanho excessivo (anti open-redirect); fallback por recurso; sem JS, sem duplicação por controller. **Preservação de filtros/contexto** entre lista↔detalhe↔edição: listas levam `return_to=fullpath` (busca/filtros/paginação/per_page/aba) em Ver/Editar/Excluir; detalhes (Voltar/Editar/Excluir), forms (hidden + Cancelar) e pages new/edit honram o contexto; **busca global** abre resultado e volta aos mesmos resultados; **contatos** voltam conforme origem (cliente vs aba global); **apontamentos** voltam à tarefa (#tab-time) ou à lista global conforme origem; **breadcrumbs** com `aria-label="Breadcrumb"` e sem UUID como rótulo (sem reformulação visual). Aceite do PO (busca a validar em uso); checks verdes (ver `PROJECT_STATUS.md`). **PB-013 integralmente concluída.**

### PB-014 — Código legível de tarefa

| Campo | Valor |
|---|---|
| Prioridade | P1 (decisão do PO; reabre ADR-016) |
| Status | **ENTREGUE (2026-06-22)** — aceite do PO; **addendum ao ADR-016**. |
| Problema que resolve | Tarefas eram identificadas só por UUID/URL, sem código operacional legível (ex.: `TSK-000001`) como no TaskManager — dificultava referência rápida no dia a dia. |
| Origem/evidência | Observação do PO + `PB-001_PARITY_AUDIT.md §5.3`; **ADR-016** adiou "código legível" para v1; reaberto pelo PO. |
| Critério de aceite | ✅ Código estável/legível `TSK-000001` exibido na lista e no detalhe (e demais telas onde a tarefa aparece); geração automática, única, não reutilizável. |
| Fora de escopo | tags/assignee/due_date/estimated_hours (seguem v1); rota/lookup público por código (URLs continuam por UUID). |
| Dependências | ADR-016 (addendum). |
| Relacionado | WD-04, UI-03. |

**Entrega (2026-06-22):** `tasks.code_number` (bigint) por **sequence do PostgreSQL** (`DEFAULT nextval`; concorrência segura, nunca `maximum+1`) → `Task#code` = **`TSK-%06d`**. Backfill determinístico das existentes (`created_at ASC, id ASC`); `NOT NULL` + índice **unique**; `attr_readonly` + fora dos strong params (não atribuível). **URLs continuam por UUID** (sem rota/lookup por código nesta fatia); exclusão **não reutiliza** código. Exibido na lista/detalhe de tarefas, busca global ("Encontrado em: Código"), links em demandas/conversas/apontamentos/dashboard e selects (`TSK-000001 — Título`). **Busca por código** (completo ou número, case-insensitive) em OR com texto; `%/_` escapados. Checks verdes (ver `PROJECT_STATUS.md`).

### PB-015 — Sincronização operacional de conversas

| Campo | Valor |
|---|---|
| Prioridade | P0 |
| Status | **Entregue (MVP)** — validada ponta a ponta + aceite manual do PO (2026-06-21). |
| Problema que resolve | Trazer novas conversas do VS Code (`output/normalized/`) para o Omni **sem depender de comandos Rails conhecidos pelo usuário**. |
| Origem/evidência | ADR-008/011; auditoria PB-015 (sync via rake era a única via). |
| Critério de aceite | Botão na UI enfileira importação em background, status/progresso/erros visíveis, sem o Rails executar o pipeline. |
| Fora de escopo | Disparo do pipeline pelo Rails; agendamento automático (→ PB-016). Sem timesheet/relatórios. |
| Dependências | ADR-008, ADR-011, ADR-021, ADR-005 (SolidQueue). |
| Relacionado | OP-01, OP-03, PB-004. |

**Entregue:** tela operacional `/sync_runs` com **"Atualizar conversas no Omni"** (enfileira `SyncConversationsJob`); serviço `Sync::RunConversationsSync` lê **apenas** `/normalized` (allowlist `config.x.normalized_dir`, nunca path do usuário), ordem **ImportSummaries → BuildConversationTurnRefs**, **advisory lock** anti-concorrência, **settle/verify** de fingerprint antes/depois (preserva índice anterior em falha), status agregado `SyncExecution`, **botão desabilitado + barra de progresso por etapa + auto-refresh** durante execução. Worker **`omni_jobs`** isolado no devstack (sem `SOLID_QUEUE_IN_PUMA`). Script externo `app/script/SyncOmniConversations_PB015_v1.ps1` (pipeline + enfileira import; mutex; exit codes; sem logar segredos). **Correção técnica:** falso no-op do fingerprint de turn_refs (mtime na chave + hash de cabeça/miolo/cauda). **Preservação:** upsert por `thread_id`; nunca deleta conversas; tarefas e `conversation_links` intactos. **Validação ponta a ponta (2026-06-21):** pipeline real regenerou o output → importação trouxe **12 conversas novas** (1635 → **1647 conversations**, **134653 turn_refs**); `conversation_links` e `tasks` preservados. Métricas: ver `PROJECT_STATUS.md`.

### PB-016 — Agendador interno de importação (Configurações)

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **CONCLUÍDA (2026-06-22)** — PB-016a + PB-016b entregues e aceitas pelo PO; **addendum ao ADR-011**. |
| Problema que resolve | Uso diário: o Omni deve **orquestrar a importação sozinho**, em intervalos configuráveis, **sem depender do Agendador de Tarefas do Windows**. |
| Origem/evidência | Decisão do PO; addendum ao **ADR-011**. |
| Critério de aceite | ✅ Botão "Sincronizar agora" executa **coleta (pipeline) + importação**; **Configurações** com agendador configurável rodando como **processo da própria aplicação** (SolidQueue `recurring.yml` + worker); disparo do pipeline sob **allowlist/caminho fixo + timeout + sem input + sem logar credenciais**. |
| Fora de escopo | Cancelamento de execução em andamento; histórico avançado de logs; produção/F7 (worker/agente em produção). |
| Dependências | PB-015, ADR-011 (addendum 2026-06-22). |
| Relacionado | OP-01, OP-03, WD-10 (Configurações). |

**Fatias:**

- **PB-016a — execução do pipeline pelo agente Windows (ENTREGUE 2026-06-22):** o pipeline (RepoB) é Windows-nativo (lê `%APPDATA%`/`.codex`/`.claude`; exige `APPDATA`) e **não roda no container** Linux. Solução: **agente** no host (`app/script/pipeline_agent.py`, stdlib) que o Omni aciona por **HTTP local com token**; o Rails/worker **nunca executa Python** nem monta as fontes. `Sync::PipelineRunner` (cliente HTTP: health → run) dispara o agente; `RunConversationsSync` roda **coleta antes da importação**. Segurança: **comando fixo no agente**, token, timeout, sem input do usuário, saída segura (sem credenciais/paths). **Resiliência:** agente offline → **degrada** (pula coleta, importa o output atual com aviso); falha real (exit≠0/timeout) **aborta antes de importar** (índice preservado, settle/verify da PB-015). Auto-start/auto-restart do agente no devstack (`.devstack/agent.sh` + `up.sh`). Gate por flag `OMNI_RUN_PIPELINE_INTERNALLY` (default off = comportamento PB-015). Validado ponta a ponta (coleta real, exit=0; +482 turn_refs; vínculos/tarefas preservados).
- **PB-016b — agendamento interno configurável em `/settings` (ENTREGUE 2026-06-22):** `SyncSchedule` (singleton: ligar/desligar + intervalo, allowlist 15min…24h) + `ScheduledSyncJob` recorrente (SolidQueue `recurring.yml`, tick por minuto) disparam o **mesmo fluxo** do botão manual quando vencido e sem execução ativa. **Sem Tarefa do Windows.** O agendador mora em **Configurações** (`/settings`, decisão de produto); `/sync_runs` mantém só a sincronização manual + atalho para Configurações. Status do pipeline na UI enxuto (data/hora + status; stdout cru só em erro, resumido).

### PB-017 — Auth/Admin seguro (single-user)

| Campo | Valor |
|---|---|
| Prioridade | **P0/P1** — base de segurança que antecede a próxima onda (deve vir antes de PB-018 e de qualquer exposição). |
| Status | **Pronto para execução** |
| Problema que resolve | A base de autenticação (Devise, WD-08) existe, mas o fluxo de Admin não está endurecido para uso seguro single-user: falta tratamento explícito de cadastro público, recuperação de senha e limites de tentativa. Precisa passar pelo checklist de segurança antes de avançar. |
| Origem/evidência | Decisão de produto na coordenação da onda pós-`04901b6`; base Devise já entregue (WD-08); skill/checklist **secure-auth**. |
| Critério de aceite | ✅ Admin loga; ✅ cadastro público bloqueado; ✅ reset por e-mail preparado; ✅ reset manual seguro documentado; ✅ rate limit por **IP e por conta**; ✅ **nenhuma credencial no diff**; ✅ checklist **secure-auth** documentado item a item (**PASS/GAP/N/A**). |
| Decisões | • **Uso single-user** por enquanto. • **Somente Admin** (sem papéis adicionais nesta frente). • **Sem cadastro público** (registro desabilitado/bloqueado). • **E-mail/senha do Admin (login)** e **credenciais de SMTP** são **separados** — não reaproveitar um pelo outro. • **Recuperação:** reset por e-mail **+** reset manual seguro. • Usar **Devise**, **não** auth manual/cripto caseira. • Aplicar o **checklist secure-auth**. • **Fora de escopo:** `is_active`, multiusuário, MFA, OAuth, passkeys. |
| Fora de escopo | `is_active`/desativação de conta; multiusuário; MFA/2FA; OAuth/"entrar com Google"; passkeys; qualquer cripto caseira. |
| Dependências | WD-08 (Devise), WD-09 (Pundit); skill **secure-auth**; ADR-014 (política multiusuário — segue single-user/Admin). |
| Relacionado | WD-08, WD-09, WD-10, OP-04, SEC. |

### PB-018 — Status configurável + termos PT-BR

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **IMPLEMENTADO E VALIDADO (2026-06-24) — aguardando aceite manual do PO** (checks verdes; sem commit/push). Não "Entregue" no gate até o aceite visual. |
| Problema que resolve | Tarefas e Projetos precisam de status **configuráveis** pelo usuário (nome, cor, ordem, finalizador) em vez de status fixos no código; e os termos de domínio PT-BR precisam ficar estabilizados para evitar drift de nomenclatura. |
| Origem/evidência | Decisão de produto na coordenação da onda pós-`04901b6`. |
| Critério de aceite | ✅ Status de **Tarefas e Projetos** configuráveis (campos abaixo); ✅ **Demandas permanecem fixas**; ✅ status em uso **não excluível livremente** (bloqueio claro; FK ON DELETE RESTRICT no banco); ✅ termos de domínio preservados. |
| Decisões | • **Status configurável** para **Tarefas e Projetos** agora. • **Demandas ficam fixas:** `pending`→**Pendente**, `converted`→**Convertida**. • **Campos do status:** nome, **chave/código**, cor, ordem, ativo, **finalizador**. • Status **em uso não pode ser excluído livremente** — deve ser alterado/movido para status válido antes. • **finalizador** afeta **apenas filtros/exibição** por enquanto (sem regra de negócio adicional). • **Termos preservados:** **Demanda, Apontamentos, Conversas, Sync**. • **Cliente = cliente atendido**; **Empresa prestadora = domínio futuro separado** (não nesta frente). |
| Fora de escopo | Status configurável para Demandas; workflow/transições com regra de negócio a partir de `finalizador`; reatribuição em massa de registros entre status; "Empresa prestadora" (domínio futuro). |
| Dependências | PB-017 (precede); WD-03 (Projetos), WD-04 (Tarefas); **ADR-024** (modelagem). |
| Relacionado | WD-03, WD-04, WD-05/WD-06 (Demandas — fixas), WD-10/UI-07 (Configurações). |

**Implementação (2026-06-24; aguardando aceite):** tabela `configurable_statuses` (entity_type/key/name/color/position/active/final; único entity_type+key) + **seed** dos status atuais. Integridade no **banco** via **FK composta** `(status_entity, status) → configurable_statuses(entity_type, key)` **ON DELETE RESTRICT** (CHECKs fixos de status removidos) — **ADR-024**. `tasks.status`/`projects.status` seguem como **key string** (impacto mínimo). CRUD em **Configurações** (`/settings`): criar/editar/inativar/excluir-se-não-usado (key imutável). Selects de novos registros só mostram **ativos** (+ o status atual do registro); listas/badges/show/dashboard/busca usam **rótulo+cor configurados**; **Demanda fixa** com rótulos PT-BR. `final` só visual. Suíte **671/2573/0**; rubocop 200/0; brakeman 0. Ver `DELIVERY_LOG`/`PROJECT_STATUS`.

---

## 6.1. Frente comercial — Empresa Prestadora + Contratos (Etapa 0, 2026-06-24)

> **Contrato aprovado em auditoria read-only (Etapa 0).** Modelagem em **ADR-025**. Base para **Cálculo de horas → Fechamentos → Relatórios/PDF**. **Nada implementado** nesta etapa (docs-only). **Decisões negativas:** não renomear Client→Empresa; Empresa Prestadora é domínio separado; sem User↔Prestadora agora (single-admin vê todas); sem mensalidade/pacote; sem `rounding_rule` agora; `final` (status) não vira regra comercial; não tocar TimeEntry/Task/Project nesta etapa.

### PB-019a — Empresa Prestadora (CRUD)

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **IMPLEMENTADO E VALIDADO (2026-06-24) — aguardando aceite manual do PO** (checks verdes; sem commit/push). Não "Entregue" no gate até o aceite. |
| Problema que resolve | Não existe a entidade "empresa pela qual presto o serviço" (distinta do Cliente atendido). É a base do domínio comercial (contratos, fechamentos, PDF). |
| Origem/evidência | Etapa 0 (auditoria read-only); **ADR-025**. Schema atual não tem provider/contract/valor. |
| Critério de aceite | ✅ CRUD de **`provider_companies`** com `name` NOT NULL, `trade_name`, `cnpj` (só dígitos, **único entre prestadoras**), `email`, `phone`, `address`, `active` (default true); **UI em Configurações** (`/settings`). |
| Decisões | • CNPJ **único entre prestadoras**, **sem** cruzar unicidade com `clients`. • **Logo e dados fiscais → PB-022/PDF** (não agora). • Single-admin enxerga todas (sem User↔Prestadora). • Não renomear Client→Empresa. |
| Fora de escopo | Logo/dados fiscais; vínculo User↔Prestadora (N:N futuro); contratos (PB-019b). |
| Dependências | **ADR-025**. |
| Relacionado | WD-10/UI-07 (Configurações), WD-11, PB-019b. |

**Implementação (2026-06-24; aguardando aceite):** `provider_companies` (uuid; name NOT NULL; trade_name/cnpj/email/phone/address; active default true; índice único parcial de cnpj `WHERE cnpj IS NOT NULL` — único só entre prestadoras). `ProviderCompany` normaliza CNPJ p/ dígitos (vazio→nil), único entre prestadoras, **cnpj igual a Client permitido**. **CRUD no padrão do Omni** (decisão do PO — não inline): página de **lista** + **Nova/Editar** com `_form` em card (igual Clientes/Projetos), em `/settings/provider-companies`. **Configurações virou um hub por domínio** (decisão do PO): `/settings` = índice de cards → sub-páginas `/settings/sync` (PB-016b), `/settings/status` (PB-018) e Empresa Prestadora. Controller resourceful (index/new/create/edit/update/destroy; `policy_scope`; `return_to`) + `ProviderCompanyPolicy` (ADR-014). Suíte **703/2699/0**; rubocop 0; brakeman 0. Ver `DELIVERY_LOG`/`PROJECT_STATUS`. **Contratos/Cálculo/Fechamentos/Relatórios não iniciados.**

### PB-019b — Contratos (CRUD básico)

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **IMPLEMENTADO E VALIDADO (2026-06-24) — aguardando aceite manual do PO** (checks verdes; sem commit/push). Não "Entregue" no gate até o aceite. |
| Problema que resolve | Sem contrato não há base para valorar horas, fechar períodos e emitir relatórios. |
| Origem/evidência | Etapa 0; **ADR-025**. |
| Critério de aceite | ✅ CRUD de **`contracts`** com `provider_company_id` NOT NULL, `client_id` NOT NULL, `project_id` NULL, `start_date` NOT NULL, `end_date` NULL, `modality` (**só `hourly`**), `hourly_rate` `decimal(12,4)` **NOT NULL**, `status` **enum fixo** (`draft`/Rascunho, `active`/Ativo, `suspended`/Suspenso, `ended`/Encerrado), `notes`, `active`; ✅ **UI de Contratos como item próprio na sidebar** (grupo Comercial); ✅ **validação de sobreposição** (abaixo) com testes. |
| Decisões | • Contrato = **Empresa Prestadora + Cliente**, **Projeto opcional**. • Contrato de **projeto tem prioridade** sobre o geral do cliente (no cálculo futuro). • Modalidade **só `hourly`** agora; `hourly_rate` **obrigatório**. • Status **enum fixo** (não configurável). • Monetário em **decimal** (sem float). • **Sem `rounding_rule`** (→ PB-020). |
| Regra — apontamento sem contrato | Cliente/projeto **sem contrato pode ter apontamentos**; horas existem **sem valor monetário**; **nunca bloquear** a captura de tempo por falta de contrato (UI sinaliza "sem contrato" no futuro). |
| Regra — mudança de contrato | `TimeEntry` **não grava** contrato nem valor; preview futuro calcula pelo contrato **vigente na data**; **fechamento congela snapshot**; alterar contrato depois **não altera** fechamentos já fechados. |
| Regra — sobreposição | **Permitir** contrato **geral + de projeto** no mesmo período (projeto prioritário). **Proibir** dois **gerais** sobrepostos (mesma prestadora+cliente) e dois do **mesmo projeto** sobrepostos. Implementar **validação Rails + testes** na PB-019b. |
| Fora de escopo | Cálculo/valoração (PB-020); fechamento (PB-021); PDF (PB-022); modalidades monthly/package; `rounding_rule`; constraint EXCLUDE no banco (ver risco residual). |
| Dependências | PB-019a; **ADR-025**; WD-01 (Client), WD-03 (Project). |
| Relacionado | PB-020, PB-021, PB-022. |

> **Risco residual (sobreposição):** nesta fatia a unicidade temporal é garantida **só na app (Rails)** — **sem** constraint `EXCLUDE` no banco. Risco de concorrência **baixo** no single-admin. **Endurecimento futuro possível** via PostgreSQL `EXCLUDE USING gist` + `btree_gist` (extensão **disponível** no PG 16; exige índices parciais por `project_id IS NULL`/`NOT NULL` e por status vigente).

**Implementação (2026-06-24; aguardando aceite):** `contracts` (uuid; FKs provider RESTRICT / client RESTRICT / project NULLIFY; `modality` só `hourly` + CHECK; `hourly_rate` decimal(12,4); `status` enum CHECK; `start_date` NOT NULL; `end_date` null; CHECK `end_date >= start_date`; `notes`; `active`). Model `Contract` com validações + **overlap em Rails** (geral×geral e mesmo-projeto bloqueados; geral+projeto coexistem; `ended` não ocupa; `[start, end||∞]`). CRUD padrão Omni (`ContractsController` resourceful + busca/filtros/paginação) + `ContractPolicy` (ADR-014); **sidebar grupo "Comercial" › Contratos**. `has_many :contracts` em provider/client (restrict) e project (nullify). **TimeEntry/Task intocados.** Suíte **736/2802/0**; rubocop 0; brakeman 0. Ver `DELIVERY_LOG`/`PROJECT_STATUS`. **Cálculo/Fechamentos/Relatórios/PDF não iniciados.**

### PB-020 — Apuração → Validação → Precificação (frente comercial)

> **Saneamento (2026-06-24):** a PB-020 foi **redividida** para separar **apuração de horas** (independente de contrato) de **precificação** (que usa contrato). Antes, a PB-020 fundia "cálculo de horas" com "valoração por contrato" — drift conceitual corrigido. **Premissa oficial do PO:** conversas importadas/vinculadas a tarefas são **evidência primária** de trabalho; apontamentos manuais (`TimeEntry`) também compõem a apuração; **apuração NÃO depende de contrato**; **contrato é uma forma de precificação**, não a origem da apuração; horas **sem contrato** permanecem visíveis como "sem contrato"/"sem valor". **Fluxo:** Conversas/Tarefas → **Apuração** → **Validação** → **Precificação** → **Fechamento** (PB-021) → **Relatório/PDF** (PB-022).

> **PB-020 tem DUAS frentes (esclarecimento 2026-06-25).** Esta seção (PB-020a/b/c) é a **frente comercial/tempo** (apuração→validação→precificação). A **frente de produto — Triagem de Conversas** (especificada em `PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md`) **já foi entregue/publicada em `main`** e cobre: Central/inbox read-only (`68e9e8c`) + modo triagem no detalhe (`3ae1484`); **decisão de triagem persistida mínima** (`conversation_triages`, `99bf00f`); **criar/vincular tarefa com contexto** (`0e957bf`); **atividades manuais de 2º nível** (`conversation_activity_drafts`, `e983a29`); **sugestão por IA local** Ollama/Gemma4 isolada e testada (`18b80e2`/`de58b7e`). IA sugere; humano confirma. Validação técnica (checks verdes); **produção não exercida; aceite operacional não registrado**. **Ainda pendente da frente de tempo:** classificação de gaps, validação de tempo, **rascunho de apontamento**, **promoção a TimeEntry** — que conectam a Triagem à apuração (PB-020a).

#### PB-020a — Apuração de horas trabalhadas

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **IMPLEMENTADO E VALIDADO (2026-06-24) — aguardando aceite manual do PO** (checks verdes; sem commit/push). Não "Entregue" no gate até o aceite. |
| Problema que resolve | Consolidar **horas trabalhadas** por tarefa/cliente/projeto/período a partir das evidências (apontamentos `TimeEntry` e tarefas vinculadas a conversas), **sem qualquer dependência de contrato/valor**. |
| Critério de aceite | ✅ Tela/serviço de **apuração** (`/work_time_reports`) que lista e totaliza **horas** por período + filtros (cliente/projeto/tarefa); `duration` em **segundos (Integer, sem float)**; **não** exige contrato; **não** grava em `TimeEntry`/`Task`. Horas existem mesmo sem contrato. Read-only. |
| Decisões | • **Contrato é opcional** e **não participa** desta fatia. • Conversas vinculadas (`Task#conversation_count`) contam como **evidência** (contagem), sem inferir tempo de turnos. • Sem `rounding_rule` (arredondamento só visual). |
| Fora de escopo | Qualquer valor monetário/contrato (→ PB-020c); validação/ajuste (→ PB-020b); fechamento (PB-021); PDF (PB-022). |
| Dependências | PB-003 (TimeEntry), PB-004 (tarefa/vínculo), **ADR-023** (dia operacional Brasília). |

**Implementação (2026-06-24; aguardando aceite):** service read-only `WorkTimeReport` (segundos Integer; totais geral/cliente/projeto; apontamentos + conversas vinculadas; opção "sem horas lançadas"; running não distorce; sem N+1) + `WorkTimeReportsController#index` (rota `GET /work_time_reports`; default mês atual Brasília; `skip_pundit`) + view PT-BR + sidebar **Comercial → "Apuração"**. **Sem migration/schema**; **não grava nada**; sem contrato/valor. Suíte **754/2872/0**; rubocop 0; brakeman 0. Ver `DELIVERY_LOG`/`PROJECT_STATUS`. **PB-020b/PB-020c/PB-021/PB-022 não iniciadas.**

#### PB-020b — Validação/ajuste da apuração

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **Aprovado** (depende de PB-020a). |
| Problema que resolve | Permitir **revisão humana** da apuração antes de precificar/fechar (marcar horas como conferidas, sinalizar divergências), sem alterar a fonte. |
| Critério de aceite | Mecanismo de **validação** da apuração de um período (estado "conferido"/pendências) que **precede** precificação e fechamento. Decisão de produto sobre granularidade (por período × por apontamento) — **pendente do PO** (ver §7). |
| Fora de escopo | Precificação (PB-020c); congelamento/snapshot (PB-021). |
| Dependências | PB-020a. |

#### PB-020c — Prévia de precificação (usa contrato quando existir)

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **Aprovado** (depende de PB-020a; usa PB-019b). |
| Problema que resolve | **Estimar valor** das horas apuradas aplicando o **contrato** quando houver, **sem fechar**. Apuração já existe sem isto; aqui só se acrescenta o preço. |
| Critério de aceite | **Prévia** (PT-BR; rótulos "Prévia"/"Apuração"/"Valor estimado", sem "billing/preview/unpriced") que resolve o contrato **por data do apontamento**, **prioridade Projeto > Cliente**; **sem contrato = "sem valor"** (linha visível, nunca escondida/bloqueada); `valor = horas × hourly_rate` em **decimal** (sem float); arredondamento **só visual** nesta fase (`rounding_rule` definitiva fica para fatia posterior). **Read-only**; **não** grava em `TimeEntry`/`Contract`. |
| Decisões | • Contrato é **camada de precificação**, opcional. • **Status de contrato que valoriza** (Ativo? Suspenso?): **pendente do PO** (ver §7). • Sem persistência financeira (snapshot → PB-021). |
| Fora de escopo | Fechamento/snapshot (PB-021); relatório/PDF (PB-022); `rounding_rule` comercial definitiva; gravar valor em qualquer registro. |
| Dependências | PB-020a; PB-019b (Contratos); **ADR-025**. |

### PB-021 — Fechamentos (snapshot)

| Campo | Valor |
|---|---|
| Prioridade | P1 |
| Status | **Aprovado** (depende de PB-020b/PB-020c). |
| Problema que resolve | Congelar um período **já validado** como fonte oficial e imutável para relatório. |
| Critério de aceite | Fechar um período **congela snapshot** (após a **validação**, PB-020b): empresa prestadora, cliente, contrato (quando houver), período, **horas apuradas**, **valor/hora**, **total**, **regras aplicadas**. Snapshot é a **fonte oficial** do relatório; **alterar contrato depois não altera fechamentos**. Horas **sem contrato** podem ser fechadas como horas sem valor (decisão de produto — ver §7). |
| Fora de escopo | PDF/layout (PB-022); cancelamento/reabertura avançada (a definir). |
| Dependências | PB-020b (validação), PB-020c (precificação); **ADR-025**. |

### PB-022 — Relatórios / PDF

| Campo | Valor |
|---|---|
| Prioridade | P1/P2 |
| Status | **Aprovado** (depende de PB-021). |
| Problema que resolve | Entregar o documento de horas/valores ao cliente. |
| Critério de aceite | Relatório/PDF que **consome o snapshot do fechamento** (nunca a prévia); **logo e dados fiscais** da Empresa Prestadora entram **aqui**. |
| Fora de escopo | Envio automático por e-mail (a definir); integrações fiscais. |
| Dependências | PB-021; PB-019a (dados/logo da prestadora). |

---

## 7. Próxima ação recomendada

**PB-001/PB-002 entregues**; **PB-003 concluída** (a/b/c); **PB-015 entregue (MVP)**; **PB-004 concluída** (a/b/c); **PB-005** (demandas), **PB-006** (clientes/contatos + CNPJ — ADR-022) e **PB-007** (projetos + duplicação) entregues. **As 4 listas operacionais (tarefas/demandas/clientes/projetos) estão completas — lacuna operacional da PB-001 fechada.**

**PB-013 CONCLUÍDA** — PB-013a (busca global, 2026-06-21) + PB-013b (preservação de contexto/navegação, 2026-06-22).

**PB-014 ENTREGUE** (código legível `TSK-000001`, 2026-06-22; addendum ao ADR-016).

**PB-016 CONCLUÍDA** — PB-016a (execução do pipeline pelo agente Windows) + PB-016b (agendamento interno em /settings), 2026-06-22; addendum ao ADR-011.

**Melhoria UX transversal (2026-06-23):** paginação amigável (« Primeira/Última », "Página X de Y") + "Mostrar tudo" (teto + aviso) em todas as listas e nos turnos de `/conversations/:id`. Sem item de backlog dedicado; registrada no DELIVERY_LOG/FEATURE_MATRIX.

**Onda pós-`04901b6` — concluída:** **PB-017 — Auth/Admin seguro** ENTREGUE (`477829d`, 2026-06-24; addendum ao ADR-003). **PB-018 — Status configurável + termos PT-BR** ENTREGUE (`ad1a10e`, 2026-06-24; ADR-024).

**Frente comercial (ADR-025) — andamento:** **PB-019a** (Empresa Prestadora CRUD + hub de Configurações) ENTREGUE (`54b556e`, 2026-06-24). **PB-019b** (Contratos CRUD) **IMPLEMENTADO E VALIDADO (2026-06-24) — aguardando aceite do PO**. **PB-020a** (Apuração de horas) **IMPLEMENTADA E VALIDADA — aguardando aceite do PO**; **PB-020b/PB-020c** (Validação/Precificação), **PB-021** (Fechamento) e **PB-022** (Relatórios-PDF) Aprovadas, **não iniciadas**.

**Frente de produto da PB-020 — Triagem de Conversas (andamento, 2026-06-25):** **ENTREGUE/PUBLICADA em `main`** — base read-only (`68e9e8c`/`3ae1484`), **decisão de triagem persistida mínima** (`conversation_triages`, `99bf00f`), **criar/vincular tarefa com contexto** (`0e957bf`), **atividades manuais de 2º nível** (`conversation_activity_drafts`, `e983a29`) e **sugestão por IA local** Ollama/Gemma4 isolada/testada (`18b80e2`/`de58b7e`). IA sugere; humano confirma. Validação técnica (checks verdes); **produção não exercida; aceite operacional não registrado**. Pendente (liga Triagem→apuração): classificação de gaps, validação de tempo, **rascunho de apontamento**, **promoção a TimeEntry**. Especificação em `PB-020_TRIAGEM_CONVERSAS_REQUISITOS.md`; status granular em `FEATURE_MATRIX.md` (UI-05).

**Saneamento documental (2026-06-24, docs-only):** PB-020 redividida em **PB-020a (Apuração) / PB-020b (Validação) / PB-020c (Prévia de precificação)** — corrige o drift que fundia apuração com valoração por contrato. **Apuração não depende de contrato; contrato é precificação.** Fluxo: Conversas/Tarefas → Apuração → Validação → Precificação → Fechamento (PB-021) → Relatório/PDF (PB-022).

**Próxima decisão do PO:** **aceite operacional** das fatias **implementadas/validadas — aguardando aceite** (PB-019b Contratos, PB-020a Apuração) e da **frente de Triagem** (entregue/publicada; aceite operacional ainda não registrado). **Nada novo será implementado sem autorização explícita.** Itens **não iniciados**: Validação/Precificação (PB-020b/c), Fechamentos (PB-021), Relatórios/PDF (PB-022), **frente de tempo da Triagem** (classificação de gaps, validação de tempo, rascunho de apontamento, promoção a TimeEntry), Desktop, Revisão de código. **Decisões pendentes do PO:** granularidade da validação (PB-020b); status de contrato que valoriza (PB-020c — Suspenso?); horas sem contrato no fechamento (PB-021).
