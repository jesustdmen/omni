# Omni/Continuity — Diário de Entregas

> Append-only. Entradas mais recentes no topo. **Não registrar entrega sem evidência objetiva.**

## Como usar
- Criar uma nova entrada a cada entrega real (merge/validação), nunca a cada commit.
- Sempre anexar evidência objetiva (contagem, saída de teste, critério comprovado).
- Atualizar `PROJECT_STATUS.md` e `FEATURE_MATRIX.md` na mesma sessão da entrada.

## Entradas

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
