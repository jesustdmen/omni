# ADR-011 — Estratégia de sync: agendador externo roda pipeline; Rails lê output/normalized/

## Status
Aceito — 2026-06-16 (Fase 0). **Addenda:** 2026-06-21 (PB-015 + direção do agendador interno); 2026-06-22 (PB-016 concluída **em dev/local** — disparo do pipeline pelo Omni via agente no host); 2026-06-28 (RepoB é referência não produtiva; origem produtiva de coleta/normalização a definir); 2026-06-29 (F7.7 — pipeline NATIVO internalizado em `app/pipeline`; RepoB deixa de ser runtime); **2026-07-03 (incidente de integridade — telemetria NÃO é conversa; `thread_id` restrito a fontes conversacionais).** Ver ao fim.

## Contexto
O viewer já tem botão que roda o pipeline. Settings preveem "sincronizar agora" + agendamento ("a cada 30 min", "rodar ao abrir"). Executar processo externo do Rails é superfície de risco (injeção/credencial).

## Decisão
Dois gatilhos com responsabilidades separadas:
1. Agendador de Tarefas do Windows executa o pipeline Python (gera output/normalized/).
2. Rails "sincronizar agora" apenas lê output/normalized/ e faz upsert (não dispara o pipeline por padrão).
3. Disparo do pipeline pelo Rails fica fora do MVP ou condicionado a allowlist, timeout e caminho fixo (nunca input do usuário).

## Alternativas consideradas
- Só Rails dispara — acopla Rails à presença de Python no boot; risco de command injection.
- Só agendador — perde o "sync agora" da UI.

## Consequências positivas
- Desacopla execução do pipeline da leitura; Rails não depende de Python para funcionar.

## Consequências negativas
- Dois pontos de configuração (agenda externa + leitura interna).

## Riscos
- Execução externa pelo Rails (se habilitada) = injeção/credencial.

## Critérios de aceite
- "Sync agora" funciona sem disparar pipeline; disparo (se habilitado) usa allowlist e timeout.

## O que NÃO fazer
- Nunca passar caminho/args de binário vindos de input do usuário. Não fazer o Rails depender do pipeline para subir.

## Validação futura
- Configuração segura (allowlist + timeout + path fixo) obrigatória antes de qualquer disparo de pipeline pelo Rails.

## Addendum (2026-06-21) — PB-015 entregue + direção do agendador interno (decisão do PO)
A decisão original permanece válida. Dois esclarecimentos:

1. **PB-015 entregue dentro da decisão atual:** o "sincronizar agora" do Omni (`/sync_runs` → "Atualizar conversas no Omni") **apenas lê** `output/normalized/` (allowlist `config.x.normalized_dir`, padrão `/normalized`, montado `:ro`) e faz upsert idempotente; **não dispara o pipeline**. Processamento em background (SolidQueue, worker `omni_jobs` isolado), com advisory lock contra concorrência e verificação de fingerprint (settle/verify) antes/depois. A orquestração externa (rodar o pipeline + enfileirar a importação) fica no script `app/script/SyncOmniConversations_PB015_v1.ps1` — gatilho externo previsto na decisão (item 1).

2. **Direção futura aprovada pelo PO (uso diário):** o Omni passará a ser a aplicação de uso diário e deverá **orquestrar a importação internamente** — agendador em **Configurações** (intervalos configuráveis), como **processo da própria aplicação** (SolidQueue `recurring.yml` + worker), **sem depender do Agendador de Tarefas do Windows**. Para trazer conversas novas, isso implicará o **Omni disparar o pipeline** — exatamente o caso condicionado no item 3 e em "Validação futura": permitido **somente** sob **allowlist de binário/caminho fixo + timeout + sem input do usuário + sem logar credenciais**. Item de produto: **PB-016 — Agendador interno de importação** (proposto). Esta direção **não** revoga a decisão atual; concretiza o item 3 quando a PB-016 for autorizada/implementada.

## Addendum (2026-06-22) — PB-016 CONCLUÍDA (disparo do pipeline pelo Omni, via agente no host)

A direção do addendum anterior foi implementada e **aceita pelo PO**. O item 3 da decisão ("disparo do pipeline pelo Rails… sob allowlist, timeout e caminho fixo") está agora **concretizado**, com um ajuste arquitetural importante descoberto na implementação:

- **O pipeline NÃO roda dentro do container.** O pipeline (RepoB) é Windows-nativo: lê `%APPDATA%\Code`, `~/.codex`, `~/.claude` do perfil e **exige `APPDATA`**; o Omni roda em container Linux. Montar o perfil do usuário no container seria frágil e excessivo. **Decisão:** o pipeline roda **no host**, exposto por um **agente** (`app/script/pipeline_agent.py`, stdlib) que o Omni aciona por **HTTP local com token**. O Rails/worker **nunca executa Python** nem monta as fontes; só fala com o agente e depois lê `output/normalized/` (inalterado).

- **PB-016a — execução do pipeline pelo agente Windows:** o botão "Sincronizar agora" (`/sync_runs`) dispara, em background, **coleta (pipeline via agente) + importação**. Garantias do item 3/"O que NÃO fazer" mantidas: **comando FIXO no agente** (`python run_pipeline.py`), **token compartilhado**, **timeout**, **sem input do usuário** (o cliente não passa comando/path), **saída segura** (sem credenciais/conteúdo/paths absolutos nos logs/UI). **Resiliência:** se o agente estiver offline, a sincronização **não falha** — pula a coleta e importa o `output/normalized/` atual com aviso (degradação); falha REAL do pipeline (exit≠0/timeout) **aborta antes de importar**, preservando o índice (settle/verify de fingerprint preservados da PB-015).

- **PB-016b — agendamento interno configurável em `/settings`:** `SyncSchedule` (singleton: ligar/desligar + intervalo) + `ScheduledSyncJob` recorrente (SolidQueue `recurring.yml`, tick por minuto) disparam o **mesmo fluxo** do botão manual quando vencido e sem execução ativa. **Sem Agendador de Tarefas do Windows.** O agendador mora em **Configurações** (decisão de produto), não em `/sync_runs`.

- **Compatibilidade:** com o disparo interno **desligado** (default `OMNI_RUN_PIPELINE_INTERNALLY=false`), o comportamento é idêntico à PB-015 (só importa `/normalized`). O script PowerShell (PB-015) permanece como fallback, não como fluxo principal.

A decisão original e seus invariantes permanecem válidos; este addendum apenas registra **como** o item 3 foi realizado (agente no host) e que a PB-016 está **integralmente concluída em dev/local** (a+b). Ver o addendum de 2026-06-28 para a fronteira de produção.

## Addendum (2026-06-28) — RepoB é referência não produtiva; coleta/normalização de produção a definir (correção de direção)

> Correção de direção do PO, **sem revogar** a decisão nem o que foi entregue. Esclarece a fronteira **dev × produção** da coleta/normalização, que estava ambígua nos addenda anteriores.

- **RepoB (`_origem/_repob`) é somente leitura / referência técnica** (contrato/normalização — ADR-007/008) e **não existirá em produção**. O Omni **não pode depender do RepoB como componente executável** no fluxo produtivo.
- **O agente atual (`pipeline_agent.py` → `run_pipeline.py` do RepoB, `OMNI_PIPELINE_DIR=…/_repob/pipeline`) é ANDAIME DE DESENVOLVIMENTO.** Ele viabiliza o uso diário **local** (PB-016 a+b validada em dev/local), mas **não** é a topologia de produção.
- **PB-016 está concluída em dev/local, não pronta para produção:** a coleta produtiva depende de uma **origem própria do Omni** para `output/normalized/` — componente **versionado/deployado pelo Omni** (ou oficialmente definido como do Omni), **ainda a definir** (rastreado em F7.7 — Topologia do pipeline; ver `F7_CONTRACT_DECISIONS.md`/`ROADMAP.md`).
- **Consumo permanece válido:** o Rails consumir `output/normalized/` (ADR-008) e o mount `/normalized:ro` continuam corretos como **contrato de consumo/dev**; isso **não resolve por si só** a **origem produtiva** dessa saída (F7.5/F7.7 abertas).
- **Em desenvolvimento**, RepoB pode seguir como referência read-only e o agente como andaime; **em produção**, nada no caminho de execução do Omni pode depender de RepoB.

## Addendum (2026-06-29) — F7.7: pipeline NATIVO internalizado; RepoB deixa de ser runtime

> Concretiza a direção do addendum de 2026-06-28. O pipeline produtivo de coleta/normalização **passou a ser do Omni**.

- **Internalização:** o código produtivo (ingest → normalize + `lib`) foi copiado **verbatim** (sem refactor) para **`app/pipeline/`**, com um entrypoint nativo **`run_collect.py`** (ingest→normalize, **sem** report). `03_report`/`viewer` ficaram de fora (não fazem parte do contrato consumido pelo Omni). Pipeline é **stdlib-only**.
- **Contrato produtivo (corrigido):** obrigatórios `summaries.jsonl`, `sessions.jsonl`, `shards/{messages,summaries}/*`. `session_titles.json`/`tags.json` são artefatos do **viewer** (fora desta frente; o Omni trata `session_titles.json` como opcional e não consome `tags.json`).
- **Paridade A/B (Gate 3):** legado × nativo sobre o **mesmo snapshot** e estado fresh → `summaries.jsonl`/`sessions.jsonl` **SHA256 idênticos**, shards e contagens iguais. **Zero divergências.**
- **Troca de runtime:** o agente (`script/pipeline_agent.py`) roda `app/pipeline/run_collect.py` (`OMNI_PIPELINE_DIR` default = `app/pipeline`); o mount `/normalized` passa a vir de `app/pipeline/output/normalized` (`.devstack`). **O Omni não depende mais de `_origem/_repob` em runtime.** A orquestração (SyncSchedule/ScheduledSyncJob/SyncConversationsJob/RunConversationsSync/ImportSummaries/BuildConversationTurnRefs) e a resiliência PB-016 (agente offline degrada; `OMNI_RUN_PIPELINE_INTERNALLY=false` = só importa) **permanecem inalteradas**.
- **Validação Omni (Gate 5):** import + turn_refs a partir do output nativo (covered 1665/1665); conversations/tasks/conversation_links preservados; suíte verde.
- **RepoB:** permanece como **referência read-only** (e fonte de A/B temporário). Não é dependência executável.
- **Default operacional de DEV (devstack):** a partir de 2026-06-29 o `.devstack` (`up.sh`/`jobs.sh`) sobe o ambiente local **com a coleta LIGADA por padrão** (`OMNI_RUN_PIPELINE_INTERNALLY=1`) e inicia agente+worker, para que `/sync_runs` reflita "coleta + importação" no uso diário. **Isto NÃO altera a decisão nem o default de runtime do Rails**, que segue **`false`** em `config/application.rb`: **produção e testes/CI não coletam por acidente** (a suíte injeta runner falso). Ligar a coleta é responsabilidade do devstack; desligar no local: `OMNI_RUN_PIPELINE_INTERNALLY=0`.

## Addendum (2026-07-03) — Incidente de integridade: telemetria NÃO é conversa; `thread_id` restrito a fontes conversacionais

> Correção de contrato de importação após incidente de mistura de conversas entre workspaces. **O pipeline (F7.7) permanece intocado** — o grão dele sempre foi `(source, session_id, thread_id)`; o defeito era o Rails colapsar tudo por `thread_id`.

- **Incidente:** o mesmo `thread_id` aparece legitimamente em múltiplos workspaces/fontes porque as fontes de **telemetria/metadado** (`chat_editing_state` = telemetria de edição, `agent_sessions` = cache de estado, `chat_session_index` = índice de títulos) **reutilizam o uuid da conversa**. O import por `thread_id` puro fundia telemetria+conversa (74 colisões multi-workspace; 81% das `conversations` eram fantasmas de telemetria; 76% dos turn_refs eram telemetria `role=system`).
- **Decisão:** **telemetria não é conversa.** `Conversation` e `conversation_turn_refs` nascem **somente** de fontes CONVERSACIONAIS (lista fechada em `Sync::Sources`: `chat_session_json|chat_session_jsonl|copilot_jsonl(_raw)|codex_session|claude_code_session|openai_chatgpt`); fonte desconhecida/ausente também fica de fora. `chat_editing_state`/`agent_sessions`/`chat_session_index` seguem no normalized como **evidência/telemetria/índice auxiliar** (uso futuro), nunca como identidade.
- **Identidade:** `thread_id` **permanece a chave canônica** da conversa, restrita às fontes conversacionais (medição: 0 colisões multi-workspace nesse recorte). Chave composta com workspace foi rejeitada: quebraria a mesma sessão (`json`+`jsonl`) e workspaces re-hasheados. **Salvaguarda:** famílias conversacionais distintas com o mesmo `thread_id` não se mesclam em silêncio (skip + item de auditoria).
- **Operação:** telemetria ignorada é contabilizada (`skipped` + item agregado por execução; `skipped_telemetry` no report de turn_refs) e **não degrada o status** do run; conflito de família degrada (anomalia). **Sync agendado foi DESLIGADO temporariamente** (SyncSchedule) e triagem de conversas novas está suspensa até a reconstrução do banco.
- **Reconstrução (etapa posterior, com autorização):** dry-run `sync:integrity_report` classifica o banco (2026-07-03: 1693 conversas = 305 reais + 29 contaminadas reparáveis in-place + 1359 fantasmas; **0 com vínculo humano**); plano = backup `pg_dump` → reimport corrigido → remoção de fantasmas **sem vínculo humano** → rebuild de turn_refs.
