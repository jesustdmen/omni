# PB-020 — Requisito de Produto: Triagem de Conversas, Atividades e Tempos

> Registro de planejamento/requisito levantado em 2026-06-24. Este documento preserva a memoria da conversa de produto antes de alterar backlog, ADRs ou implementar codigo.

## 1. Visao de produto

O Omni deve transformar conversas tecnicas do VS Code em trabalho operacional rastreavel.

Fluxo desejado:

```text
VS Code
-> Omni importa/normaliza conversas
-> identifica contexto provavel
-> triagem manual/assistida
-> conversa vira tarefa ou se vincula a tarefa
-> Omni sugere atividades e apontamentos
-> usuario valida/ajusta
-> TimeEntries oficiais
-> apuracao
-> validacao
-> precificacao
-> fechamento
-> relatorio
```

A PB-020a atual, baseada em `TimeEntry` existente, continua util, mas nao representa o inicio real do fluxo. A entrada operacional desejada e a conversa importada.

## 2. Decisoes de requisito ja alinhadas

### Uma conversa pode gerar varias atividades

Uma conversa longa pode durar dias e ter um fim unico, mas conter varias atividades de segundo nivel.

Exemplo citado: entrega de um Balanco de Estoque auditado, envolvendo validacao de notas de entrada/saida, criacao de ferramentas auxiliares, consultas auxiliares, validacao de XMLs e ajustes diversos.

Requisito: o Omni deve permitir que uma conversa tenha um objetivo principal e sugira atividades/tarefas de segundo nivel, sem exigir granularidade excessiva.

### IA local pode ajudar, mas nao decidir sozinha

Pode ser avaliado o uso de IA local ja existente, como Gemma, para sugerir:

- objetivo principal da conversa;
- atividades de segundo nivel;
- resumo operacional;
- cliente/projeto provavel;
- descricao de apontamentos.

Regra de produto: IA local deve atuar como assistente de sugestao, nao como decisor final.

### Timestamps sao evidencia, nao relogio absoluto

Conversas longas com pausas nao devem virar automaticamente um apontamento unico nem varios apontamentos definitivos sem revisao.

O metodo de apuracao existente registra os principios:

- o chat sozinho nao representa todo o trabalho executado;
- gaps entre mensagens nao devem ser tratados automaticamente como pausa;
- o calculo deve partir da sequencia de trabalho e descontar apenas ausencias comprovadas;
- evidencias do workspace podem estender blocos de trabalho quando houver coerencia;
- cada gap relevante deve ser destacado para validacao do usuario.

Referencia externa citada:

```text
C:\Sandbox_BI\Brakko\Em Desenvolvimento\_docs\Metodo_Apuracao_Horas_Trabalhadas.md
```

### Cliente/projeto por workspace exige confirmacao

O Omni pode sugerir cliente/projeto usando:

- `conversations.workspace_hash`;
- `workspace_maps.folder`;
- `clients.workspace_paths`.

Mesmo quando houver casamento forte por workspace, o sistema deve pedir confirmacao humana antes de assumir o cliente/projeto.

### Conversas sem cliente entram em fila propria

Conversas sem cliente identificado devem aparecer no Dashboard ou em uma fila de triagem como "sem cliente".

### Relatorio nasce da validacao

O formato de validacao/saida desejado se aproxima da planilha existente:

```text
C:\Sandbox_BI\Brakko\Em Desenvolvimento\_docs\Lista Horas Trabalhadas.xlsx
```

Estrutura observada da aba `Horas`:

- Dia;
- Hora Ini;
- Hora Fim;
- Tempo Real;
- Acumulado;
- Descricao do Assunto.

## 3. Objetos conceituais propostos

### Triagem da Conversa

Estado/decisao humana sobre a conversa importada.

Possiveis estados:

- pendente;
- cliente sugerido;
- sem cliente;
- vinculada a tarefa;
- tarefa criada;
- ignorada / nao trabalho;
- pessoal;
- revisada.

### Atividade Sugerida

Atividade de segundo nivel detectada dentro da conversa.

Pode virar:

- tarefa;
- checklist;
- descricao de apontamento;
- evidencia no relatorio.

### Apontamento Sugerido

Candidato a `TimeEntry`, ainda nao oficial.

Campos conceituais:

- data;
- hora inicial;
- hora fim;
- duracao sugerida;
- assunto/descricao;
- conversa de origem;
- tarefa relacionada;
- gaps pendentes;
- decisao do usuario.

Regra: `TimeEntry` oficial so nasce apos validacao humana ou regra explicitamente aprovada.

## 4. Sequencia de produto recomendada

1. **Triagem operacional de conversas**
   - Dashboard com conversas pendentes.
   - Fila "sem cliente".
   - Sugestao de cliente/projeto por workspace.
   - Confirmacao humana.
   - Criar tarefa ou vincular a tarefa existente.

2. **Atividades sugeridas por conversa**
   - Sugerir objetivo principal e atividades de segundo nivel.
   - Opcional: usar IA local.
   - Nao criar tarefa automaticamente sem revisao.

3. **Apontamentos sugeridos**
   - Aplicar metodo de apuracao sobre timestamps e evidencias.
   - Destacar gaps.
   - Permitir classificar gap como pausa, almoco, trabalho fora do VS Code ou continuidade.
   - Exportar/visualizar em formato semelhante a planilha de horas.

4. **Conversao para TimeEntry oficial**
   - Usuario valida e promove sugestoes para apontamentos oficiais.
   - A partir daqui a PB-020a atual pode apurar horas oficiais.

5. **Apuracao, validacao, precificacao, fechamento e relatorio**
   - PB-020a: apuracao de TimeEntries oficiais.
   - PB-020b: validacao da apuracao.
   - PB-020c: precificacao por contrato.
   - PB-021: fechamento/snapshot.
   - PB-022: relatorio/PDF.

## CONTRATO PB-020d — Rascunhos de blocos de trabalho na Triagem (registrado em 2026-06-29)

> **Status (2026-06-29): IMPLEMENTADO E VALIDADO** (tabela `conversation_work_blocks` + UI na Triagem; suite 918/0; rubocop/brakeman 0). **Aceite operacional do PO pendente.** Inclui a regra: **conversa pessoal nao participa** (nao gera/edita bloco — bloqueio backend + UI). Detalhe da entrega no `DELIVERY_LOG`; status granular no `FEATURE_MATRIX` (UI-05) e no `PRODUCT_BACKLOG` (PB-020d). O contrato abaixo permanece como especificacao.

Decisao de produto: a unidade da proxima fatia nao e a conversa inteira nem cada microatividade isolada. A unidade e um **bloco/turno de trabalho dentro de uma conversa**, associado a um cliente e contendo varias microatividades/execucoes.

Modelo conceitual:

```text
Conversa
-> Cliente
-> Atividade macro
-> Blocos de trabalho por turno/dia
-> Microatividades/execucoes dentro do bloco
-> Rascunho validavel futuramente para TimeEntry
```

Exemplos de bloco:

```text
29/06/2026 - Manha - 08:00 as 11:00
Cliente X
Atividade macro: Analise de inconsistencia fiscal
Microatividades: revisar ata, testar ERP, consultar banco, validar hipotese

29/06/2026 - Tarde - 12:00 as 18:00
Cliente X
Atividade macro: Correcao e validacao
Microatividades: ajustar regra, testar cenario, revisar evidencias
```

Decisoes da fatia:

- O fluxo nasce e continua na **Triagem**.
- A primeira fatia cria/edita apenas **rascunhos de blocos de trabalho**.
- A primeira fatia **NAO promove para `TimeEntry`**.
- A promocao para `TimeEntry` fica para fatia posterior, apos validacao humana.
- Tipos permitidos nesta fase: `execution` e `gap`.
- Termos como situacao, analise, decisao, teste e aceite sao contexto narrativo, nao taxonomia automatica nesta fase.
- A conversa e a evidencia padrao do bloco.
- **Conversa pessoal (`personal=true`) NAO participa da avaliacao de trabalho:** nao gera nem edita bloco; nao vira Task/TimeEntry; nao entra em calculo de tempo. Bloqueio no **backend** (validacao de model + guarda no controller) e na **UI** (card desabilitado com a mensagem "Conversa marcada como pessoal. Blocos de trabalho nao sao gerados para conversas pessoais.").
- Evidencia extra so deve ser indicada quando houver trabalho fora do chat, como consulta em banco, teste em ERP, espera longa ou validacao externa.
- O tempo sugerido deve seguir o metodo de extracao ja documentado nesta PB.
- Timestamps e gaps sao evidencias, nao verdade absoluta.

Fora de escopo desta fatia:

- Criar `TimeEntry` oficial.
- Precificacao, fechamento ou PDF.
- Classificacao automatica fina de situacao/analise/decisao/teste/aceite.
- Criar fluxo separado fora da Triagem para revisar rascunhos.
- Tratar gap automaticamente como pausa ou ausencia.

## 5. Armadilhas a evitar

- Criar `TimeEntry` definitivo diretamente a partir de timestamps.
- Tratar uma conversa longa como uma unica tarefa obrigatoria.
- Tratar workspace como verdade absoluta de cliente/projeto.
- Usar IA local para decidir sem explicacao ou confirmacao.
- Misturar apuracao de horas oficiais com triagem de conversas pendentes.

## 6. Proxima decisao recomendada

Antes de mandar implementacao ao executor, desenhar e aprovar o fluxo da **Triagem de Conversas**:

- estados da conversa;
- cards/filas do Dashboard;
- confirmacao de cliente/projeto;
- criacao/vinculo de tarefa;
- relacao entre conversa, atividade sugerida, apontamento sugerido e `TimeEntry`.

---

## CONTRATO FUTURO DA TRIAGEM (registrado em 2026-06-25)

> Este bloco formaliza que o **mockup aprovado** representa a **visao futura** da Triagem. A **entrega atual e propositalmente read-only** (base). Nada aqui promete que ja existe. Serve para que o mockup nao se perca e para guiar as proximas fatias **sem misturar camadas**.
>
> Referencia visual aprovada: `_mockup/triage-dash-inbox.jsx`, `_mockup/triage-detail.jsx`, `_mockup/triage-shared.jsx`, `_mockup/spec-hifi.jsx`, `_mockup/Continuity Spec.html` (SOMENTE LEITURA — ADR-019; nao migrar codigo/assets).

## 7. O que JA EXISTE (entregue e publicado)

Publicado em `main` (`68e9e8c` Central read-only + `3ae1484` Detalhe split + `9746aff` matriz):

```text
- Central de Triagem read-only em /triage.
- Cards por estado DERIVADO (sem tabela): pendente, sem cliente, cliente sugerido, pessoal, vinculada.
- Fila principal (prioridade de triagem) e fila propria "sem cliente".
- Abertura da conversa em modo triagem via /conversations/:id?mode=triage (sem rota nova).
- Detalhe split read-only: timeline/turnos a esquerda; evidencias a direita.
- Cliente provavel apenas como SUGESTAO (workspace -> folder -> clients.workspace_paths), com "(confirmar)".
- Gaps apenas como EVIDENCIA VISUAL (> 15 min, derivados de conversation_turn_refs.ts; sem ler o arquivo).
- Criacao de tarefa SIMPLES reaproveitando o fluxo existente (ConversationTasksController) e "Vincular" pelo form atual.
- Navegacao Triagem -> Abrir/triar -> detalhe -> Voltar (return_to preservando o filtro).
```

Servicos read-only que sustentam o atual: `ConversationTriage` (estado derivado) e `ConversationTimeline` (gaps). Nenhum grava nada.

## 8. O que FALTA do mockup (entregas FUTURAS)

> **ATUALIZACAO DE ESTADO (2026-06-25) — parte desta secao foi SUPERADA (entregue/publicada em `main`).**
> Ja NAO sao mais "futuro": **decisao humana persistida** (confirmar cliente/projeto, marcar revisada/ignorada/reabrir; tabela `conversation_triages`, `99bf00f`) — `personal` segue boolean de privacidade, nao virou status (D0.2); **vincular/criar tarefa a partir do detalhe com contexto** (`0e957bf`); **atividades de 2o nivel** como rascunhos manuais (`conversation_activity_drafts`, `e983a29`); **IA local (Ollama/Gemma4) como sugestao** — nucleo isolado + integracao que extrai do conteudo real e grava rascunhos `source=ia_local` (`18b80e2`/`de58b7e`; IA sugere, humano confirma). **CONTINUAM futuros/nao iniciados:** cards "Prontas p/ tarefa"/"Gaps a validar", filtros avancados/ordenacao/lote/"triar em sequencia"/exportar, **classificacao de gaps**, **validacao de tempo**, **rascunhos de apontamento**, **promocao para TimeEntry**. O bloco abaixo e mantido como registro do escopo original do mockup.

Registrado como visao futura (escopo do mockup; ver ATUALIZACAO acima para o que ja foi entregue):

```text
Decisao humana persistida:
- confirmar cliente/projeto sugerido;
- marcar conversa como pessoal;
- ignorar / revisar conversa;
- estados persistidos de triagem (pendente/cliente sugerido/sem cliente/vinculada/tarefa criada/ignorada/pessoal/revisada).

Cards/filtros/ordenacao avancados:
- card "Prontas para tarefa";
- card "Gaps a validar";
- filtros avancados: estado, workspace, origem, data, confianca;
- ordenacao por confianca / idade / prioridade;
- acoes em lote;
- "Triar em sequencia";
- exportar fila / resumo.

Analise extraida:
- objetivo principal sugerido;
- atividades de 2o nivel sugeridas;
- criar tarefa + atividades / checklist / subtarefas;
- vincular conversa a tarefa existente (a partir do detalhe).

Tempo:
- classificacao de gaps: pausa, almoco, fora do VS Code, continuidade, duvida;
- validacao de tempo;
- rascunhos de apontamento;
- promocao para TimeEntry oficial SOMENTE apos validacao humana.

IA:
- uso de IA local / Gemma APENAS como sugestao, nunca como decisao automatica.
```

## 9. Contratos de produto (regras que valem para toda a frente)

```text
1. Workspace SUGERE cliente/projeto, mas NAO confirma sozinho.
2. Toda confirmacao relevante deve ser HUMANA e AUDITAVEL.
3. Gaps NAO viram pausa automaticamente.
4. Timestamps sao EVIDENCIA, nao relogio absoluto.
5. Uma conversa pode gerar UMA ou VARIAS atividades/tarefas.
6. Nada vira TimeEntry oficial sem validacao humana.
7. A Triagem PRECEDE a Apuracao.
8. A Apuracao continua INDEPENDENTE de contrato.
9. Contrato entra apenas na Precificacao.
```

Estes contratos sao coerentes com o §2 deste documento, com a §5 (armadilhas) e com o ADR-025 (+ addendum 2026-06-24).

## 10. Sequencia recomendada de entregas futuras

```text
1. Triagem persistida minima:
   - confirmar cliente/projeto;
   - marcar pessoal / ignorar / revisado;
   - refletir estados nos cards/filtros (persistido quando existir; derivado quando ainda nao existir).

2. Criar/vincular tarefa evoluido:
   - criar tarefa a partir da conversa;
   - vincular conversa a tarefa existente;
   - preparar destino para atividades de 2o nivel.

3. Atividades sugeridas:
   - manual primeiro;
   - IA / Gemma depois, como sugestao.

4. Validacao de gaps / tempo:
   - classificar gaps;
   - gerar rascunhos de apontamento.

5. Promocao para TimeEntry:
   - somente depois de validacao humana.
```

---

## DIAGNOSTICO TECNICO — PROXIMA FATIA: "Triagem persistida minima" (2026-06-25)

> Diagnostico read-only (planejamento). **NOTA (2026-06-25): a fatia descrita abaixo foi IMPLEMENTADA e PUBLICADA em `main`** (`conversation_triages`, `99bf00f` — `ConversationTriageDecision` + service `ConversationTriage`; ver §8 ATUALIZACAO). O texto e mantido como o diagnostico que originou a fatia. Esta secao responde as perguntas tecnicas da fatia 1 da sequencia §10. Escopo-alvo: persistir status de revisao (open/reviewed/ignored) e confirmacao de cliente/projeto; cards/filtros passam a usar estado persistido quando existir e derivado quando nao existir. **Sem** TimeEntry, **sem** apuracao, **sem** classificar gaps, **sem** IA, **sem** acoes em lote (salvo placeholder desabilitado e documentado).

## D0. Decisoes oficiais do PO (2026-06-25) — vinculam a implementacao

> Estas decisoes foram **confirmadas pelo PO** apos a publicacao do contrato futuro (`d398c14`) e **prevalecem** sobre qualquer formulacao anterior/exemplo deste diagnostico. As secoes D2/D3/D4/D9 abaixo ja foram revisadas para refleti-las.

```text
1. Persistencia em TABELA DEDICADA `conversation_triages`. Nao usar colunas novas em `conversations`.
2. `conversations.personal` continua sendo a FONTE DE PRIVACIDADE. Nao migrar `personal` agora.
   A Triagem pode exibir "pessoal" como estado efetivo, mas NAO mistura privacidade com workflow.
3. STATUS persistidos minimos da triagem: SOMENTE `open`, `reviewed`, `ignored`.
   (Nao existem outros valores de status. "linked" segue DERIVADO de ConversationLink, nao e status.)
4. CLIENTE/PROJETO confirmado NAO e status: usa campos proprios `confirmed_client_id` e
   `confirmed_project_id`. Status = fluxo de revisao; confirmacao = decisao de vinculo comercial/operacional.
5. Confirmar cliente/projeto PODE acontecer SEM criar tarefa. A Triagem precede criar/vincular tarefa;
   criar tarefa continua sendo acao posterior.
```

## D1. Qual modelo/tabela existente pode receber a decisao?

```text
- conversations: ja tem `personal` (boolean) e `user_id`; NAO tem campos de decisao de triagem
  (sem triaged_at/triaged_by/ignored/reviewed; sem client_id/project_id direto).
- conversation_links: liga conversa -> TASK (nao a cliente/projeto direto); confirmar cliente
  na pratica ja acontece ao criar/vincular tarefa (a tarefa carrega client/project).
- workspace_maps: hash -> folder (origem da SUGESTAO de cliente), nao guarda decisao humana.
Conclusao: nao ha hoje um lugar adequado para a DECISAO HUMANA de triagem (alem de `personal`).
```

## D2. Tabela nova (decisao oficial: dedicada)

```text
DECIDIDO (D0.1): tabela DEDICADA `conversation_triages` (1:1 com conversation; criada on-demand
quando ha decisao). NAO usar colunas novas em `conversations`.
Racional: nao poluir `conversations` (linha grande, sync reescreve metadados); manter a decisao
humana isolada e auditavel, sem competir com o estado DERIVADO (que continua valido quando nao ha linha);
acomodar campos futuros (objetivo/atividades) sem inchar a conversa.
```

## D3. Campos necessarios (tabela minima)

```text
conversation_triages:
- id (uuid)
- conversation_id (uuid, FK ON DELETE CASCADE, UNIQUE)         # 1:1
- status (text, NOT NULL, default 'open')                      # CHECK allowlist: SOMENTE open|reviewed|ignored (D0.3)
                                                               #   -> status = FLUXO DE REVISAO. NAO inclui cliente/pessoal/linked.
- confirmed_client_id (uuid, FK clients, nullable)             # CAMPO PROPRIO (D0.4) — NAO e status
- confirmed_project_id (uuid, FK projects, nullable)           # CAMPO PROPRIO (D0.4) — projeto opcional, coerente com contratos
- note (text, nullable)                                        # motivo de ignorar/observacao
- triaged_by_id (bigint, FK users)                             # quem decidiu (auditoria)
- created_at / updated_at
Observacoes:
- `personal` NAO entra aqui: continua em `conversations.personal` (D0.2) — privacidade, nao workflow.
- "linked" NAO entra aqui: segue DERIVADO de ConversationLink (D4).
- NAO inclui campos de tempo/atividade/gap/IA (fatias futuras).
```

## D4. Compatibilidade com o estado derivado atual

```text
- Regra de leitura: estado EFETIVO compoe DUAS dimensoes, sem misturar privacidade com workflow:
    (a) PRIVACIDADE: `conversations.personal` (boolean) — fonte unica de "pessoal" (D0.2);
    (b) WORKFLOW: `conversation_triages.status` (open|reviewed|ignored) quando houver linha;
        sem linha, vale o estado DERIVADO atual (ConversationTriage.derive).
- `personal` NAO migra para status (D0.2): segue boolean em conversations. A Triagem pode EXIBIR
  "pessoal" como estado efetivo, mas a decisao de privacidade nao vira valor de status.
- `linked` continua DERIVADO de ConversationLink (nao duplicar verdade): a tabela nao guarda "linked".
- confirmacao de cliente/projeto e ORTOGONAL ao status: uma conversa pode estar `open` e ja ter
  `confirmed_client_id`; ou `reviewed` sem cliente. Cards/filtros tratam status e confirmacao separadamente.
- ConversationTriage ganha um caminho que, dado um indice de decisoes (conversation_id => registro),
  sobrepoe o status derivado — mantendo index_for sem N+1 (1 query a mais para carregar as decisoes da janela).
- Cards/filtros: contadores passam a considerar o estado efetivo; filtro por estado idem.
```

## D5. Como auditar a decisao humana

```text
- triaged_by_id (quem) + updated_at (quando) na propria linha.
- status com allowlist (CHECK no banco) — nada de valor livre.
- confirmacao de cliente/projeto via FK (clients/projects), nunca string solta.
- opcional (futuro): tabela de eventos/historico se o PO exigir trilha completa; nesta fatia, a linha 1:1 basta.
```

## D6. Controllers/views/services tocados

```text
- NOVO model ConversationTriageDecision (ou nome a definir) + migration aditiva (tabela nova).
- TriageController#index: carregar decisoes da janela e calcular estado efetivo (sem N+1).
- conversations_controller / nova acao de update de triagem (ex.: PATCH /conversations/:id/triage)
  OU um controller dedicado triage_decisions — sem duplicar o show.
- ConversationTriage (service): aceitar override por decisao persistida.
- Views: /triage (cards/filtros usam estado efetivo) e _triage.html.erb (botoes de confirmar cliente /
  marcar pessoal / ignorar / revisar — acoes reais, com return_to).
- Pundit: policy para a decisao (ADR-014: user.present?), skip onde for read-only.
```

## D7. Testes necessarios

```text
- model: validacoes (status allowlist, unicidade 1:1, FKs), defaults.
- service: estado efetivo = persistido quando existe; derivado quando nao existe; index_for sem N+1.
- integracao: confirmar cliente persiste e reflete no card/filtro; marcar pessoal; ignorar/revisar;
  conversa pessoal segue com conteudo oculto; nada cria TimeEntry; auditoria (triaged_by) gravada.
- regressao: estado derivado puro (sem linha) continua identico ao atual.
```

## D8. Riscos para ConversationLink, Task, Client, Project e TimeEntry

```text
- ConversationLink: NAO alterar; `linked` permanece derivado dele (evitar dupla verdade).
- Task: confirmar cliente NAO deve, por si, criar tarefa; criar tarefa segue no fluxo existente.
- Client/Project: confirmed_client_id/confirmed_project_id sao FKs nullable; excluir cliente/projeto
  com decisoes apontando exige politica (nullify recomendado) — nao bloquear exclusao por triagem.
- TimeEntry: INTOCADO nesta fatia (regra de produto: nada vira TimeEntry sem validacao humana).
- Sync de conversas: a importacao reescreve metadados de `conversations`; a tabela separada de triagem
  evita que o sync apague decisoes humanas (risco real se a decisao morasse em colunas reescritas).
```

## D9. Menor implementacao segura

```text
1. Migration aditiva: tabela conversation_triages (D3) com FK/CHECK/UNIQUE; sem tocar tabelas existentes.
2. Model + Pundit policy.
3. Uma acao de update (confirmar cliente / pessoal / ignorar / revisar) com auditoria (triaged_by) e return_to.
4. ConversationTriage passa a sobrepor o derivado com a decisao persistida (sem N+1).
5. /triage e _triage.html.erb exibem estado efetivo e as acoes reais; manter "linked" derivado.
6. NAO incluir: classificacao de gap, atividades, rascunho de apontamento, TimeEntry, IA, lote.
Resultado: primeira camada de PERSISTENCIA da triagem, isolada, auditavel, reversivel, sem mexer
em TimeEntry/Apuracao/contrato.
```

> **Recomendacao do executor:** a fatia e viavel e de baixo risco com uma **tabela nova aditiva**
> (a entrega atual foi deliberadamente "sem tabela"; persistir exige sair desse contrato). As quatro
> decisoes que estavam em aberto **ja foram resolvidas pelo PO** (ver D0): (a) **tabela dedicada**
> `conversation_triages`; (b) **`personal` continua boolean** (nao migra); (c) status = **somente
> `open`/`reviewed`/`ignored`**; (d) **confirmar cliente/projeto pode ocorrer sem criar tarefa**, em
> **campos proprios** (`confirmed_client_id`/`confirmed_project_id`), nunca como status. Implementacao
> so apos autorizacao explicita do PO.

---

## VOCABULARIO CANONICO DA TRIAGEM (PT-BR) — 2026-06-25

> Regra de linguagem do Omni. **UI, mensagens e documentacao usam PT-BR.** Nomes
> tecnicos internos (tabela, coluna, enum, classe, metodo, rota tecnica, chave de
> simbolo) **podem** permanecer em ingles por convencao do Rails, mas **nao devem
> vazar para o usuario final** (tela/doc/texto de teste descritivo). Quando um termo
> interno aparece na tela, expor sempre o rotulo PT-BR correspondente.

Rotulos oficiais dos **estados efetivos** exibidos (chave interna → rotulo PT-BR):

```text
linked    -> Vinculada
personal  -> Pessoal
ignored   -> Ignorada
reviewed  -> Revisada
suggested -> Cliente sugerido
noclient  -> Sem cliente
pending   -> Pendente
```

Rotulos oficiais do **status persistido** da decisao de triagem:

```text
open     -> Aberta
reviewed -> Revisada
ignored  -> Ignorada
```

Outros termos canonicos:

```text
Triagem                 (nao "inbox")
Decisao de triagem      (status persistido: Aberta/Revisada/Ignorada)
Estado efetivo          (derivado + decisao persistida; evitar "overlay")
Estado derivado         (calculado de vinculo/workspace/pessoal)
Cliente sugerido        (sugestao por workspace; pede confirmacao humana)
Cliente confirmado      (decisao humana; campo proprio confirmed_client_id)
Confirmacao humana      (nao "confirmed" em texto de UI)
Lista permitida         (nao "allowlist" em texto de UI/doc/teste)
Somente leitura         (nao "read-only" em texto de UI/doc/teste)
```

Onde os termos internos podem ficar em ingles (sem vazar):

```text
- tabela `conversation_triages`; colunas status/confirmed_client_id/confirmed_project_id/triaged_by_id;
- valores de status no banco/enum: open|reviewed|ignored (CHECK + lista permitida no model);
- classe ConversationTriageDecision (model) e ConversationTriage (service de estado efetivo);
- rota tecnica aninhada `conversation_triage` (PATCH);
- campos de simbolo do Struct Result (state/persisted_status/...), expostos via rotulo PT-BR.
```

---

## IA LOCAL (Gemma4 via Ollama) — PREMISSA → IMPLEMENTADA (atualizado 2026-06-25)

> **ATUALIZACAO (2026-06-25): a integracao foi IMPLEMENTADA e PUBLICADA em `main`** — nucleo isolado `Ai::OllamaClient` (endpoint nativo `POST /api/chat`; `OMNI_OLLAMA_URL`/`OMNI_OLLAMA_MODEL`) + `Ai::SuggestConversationActivities` (`18b80e2`) e `Ai::ConversationContextBuilder` que extrai do **conteudo real** via `LazyLoader`/ADR-021 + `PiiRedactor`, gravando rascunhos `source=ia_local` (`de58b7e`). Contrato da API nativa corrigido em `docs/ia_local_ollama_gemma4_api.md`. **IA sugere; humano confirma**; conversa pessoal/indice `:stale` ⇒ sem sugestao (degrada com seguranca); nao cria Task/TimeEntry, nao altera ConversationLink. Testes nao dependem do Ollama real. Pendencia operacional (indice de turnos `:stale` / runtime desktop) registrada na secao "PENDENCIA FUTURA — Desktop Runtime". O texto abaixo e mantido como o registro original da premissa.

> Detalha a regra geral do §2 ("IA local pode ajudar, mas nao decidir sozinha") com o
> ambiente real informado pelo PO. **Registro documental apenas — NAO faz parte de
> nenhuma fase atual; nada de Ollama/adapter/prompt/parsing foi implementado.**

Premissa informada pelo PO:

```text
1. O PO informou que ha Gemma4 configurado localmente via Ollama.
2. Em fase FUTURA, essa IA local podera sugerir:
   - objetivo principal da conversa;
   - atividades de 2o nivel;
   - possivel resumo da tarefa;
   - possiveis descricoes de apontamento.
3. A IA local NAO decide nada automaticamente.
4. Toda sugestao precisa de CONFIRMACAO HUMANA.
5. A integracao com Ollama/Gemma4 NAO faz parte da fase atual.
```

Quando for implementada, a integracao tera **diagnostico proprio** cobrindo, no minimo:

```text
- confirmar o nome/tag REAL do modelo no ambiente local (ex.: `ollama list`) antes de codar;
- adaptador/servico ISOLADO (porta/cliente dedicado), sem acoplar Triagem ao provedor de IA;
- timeout, tratamento de erro e fallback explicitos;
- falha da IA NAO bloqueia Triagem, criacao/vinculo de tarefa nem apuracao
  (degradacao graciosa: sem sugestao, fluxo manual segue normal);
- nenhuma sugestao vira `TimeEntry` sem validacao humana (reforca §9.6 do contrato futuro).
```

Coerencia com os requisitos primordiais: a IA entra como **camada de sugestao** sobre o
fluxo ja existente (criar/vincular tarefa, decisao de triagem); **cliente sugerido por IA
continua diferente de cliente confirmado** (confirmacao humana prevalece — ver D0/§9).

---

## PENDENCIA FUTURA — Desktop Runtime / Servicos Autopersistidos (registrada em 2026-06-25)

> Registro de produto (NAO implementado nesta fase). Levantado durante a entrega da IA
> local na Triagem: a sugestao por IA depende do **indice de turnos** (`conversation_turn_refs`,
> ADR-021) estar atualizado. Quando o `output/normalized/sessions.jsonl` muda e o indice
> nao e reconstruido, o `LazyLoader` retorna `:stale`, o `Ai::ConversationContextBuilder`
> devolve contexto vazio e a Triagem **degrada com seguranca** (mensagem "Nao ha contexto
> textual suficiente para sugerir atividades com seguranca"). Hoje a reindexacao e **manual**
> (`bin/rails sync:turn_refs[...]`), o que e aceitavel no ambiente de dev atual (devstack
> Docker), mas **nao** para a futura versao desktop entregue ao usuario final.

Requisitos para a futura versao **desktop** (web + banco + Ollama + sync de conversas +
indexador de turnos como **servicos autopersistidos**, sem dependencia de comando manual):

```text
1. Web, banco (PostgreSQL), Ollama, sync de conversas e indexador de turnos devem ser
   gerenciados como SERVICOS AUTOPERSISTIDOS (sobem com o app; reiniciam sozinhos).
2. O Omni deve DETECTAR indice de turnos `:stale` (fingerprint divergente do arquivo atual).
3. O usuario NAO deve depender de rodar `sync:turn_refs` manualmente.
4. A UI/desktop deve ter HEALTHCHECK / status operacional dos servicos (web, banco, Ollama,
   sync, indexador) — visivel ao usuario.
5. A REINDEXACAO deve ser automatica (ao detectar `:stale`) ou acionavel com seguranca pela UI.
```

Coerencia: mantem a degradacao graciosa atual (sem indice = sem sugestao por IA, fluxo
manual segue), mas remove o passo manual e torna o estado dos servicos observavel. Quando
for implementar, exige diagnostico proprio (provavel addendum ao ADR-021/ADR-011 e ao
plano de empacotamento desktop).
