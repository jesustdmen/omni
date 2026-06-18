# ADR-021 — Lazy-load de turnos via índice de offsets em `sessions.jsonl`

## Status
Aceito — 2026-06-17 (pré-Fase 5). Complementa o **ADR-009** (turnos lazy/sob demanda) e o
**ADR-018** (addendum: shards por arquivo-fonte; turnos fora da F3). Não substitui nenhum.

## Contexto
- A **F3** importou **metadados** de **1635 conversas** (`summaries.jsonl`), sem turnos.
- A **F3.UI.1** permite **visualizar metadados** read-only (`/conversations`, `/sync_runs`).
- O **F4 MVP** permite **vínculo manual conversa↔tarefa** (`conversation_links`).
- A **F5** (UI de conversa) depende de **abrir os turnos reais** de uma conversa.
- **Decisão de fronteira mantida:** **não** importar o conteúdo completo de `sessions.jsonl` para o
  banco agora (volume + conteúdo sensível). O ADR-018 já previa decidir a estratégia de lazy-load
  **antes da F5, em registro próprio** — este ADR é esse registro.
- Leitura de prontidão (2026-06-17, somente leitura sobre `_origem/_repob`, sem processamento em massa)
  fundamenta as decisões abaixo.

## Fonte dos turnos (observado, somente leitura)
- **`_origem/_repob/pipeline/output/normalized/sessions.jsonl`** — coberto pelo **ADR-008**
  (`output/normalized/`); **sem** exceção nova (diferente da F3.3/ADR-020).
- Formato **NDJSON** (1 objeto JSON por linha); **UTF-8**; **~229 MiB** (240.091.231 bytes);
  **129.500 linhas**.
- **`thread_id` presente** nas linhas verificadas; **cobertura 1635/1635** contra
  `conversations.thread_id` (100%); `session_id` também cruza (1519/1519).
- Relação **conversa → turnos é 1:N** (ex.: thread `claude-code:/96856917…` → **177 linhas**,
  igual ao `message_count` do banco). Campos por linha: `source, session_id, thread_id, timestamp,
  role∈{system,user,assistant,tool}, text, tool, tool_input, files_changed[], workspace_hash,
  request_id, response_id, model_id, agent_id, agent_name, mode_name, raw_source_file`.

## Decisão
1. Adotar **lazy-load por índice de offsets** (não importar turnos para o banco).
2. **Chave canônica = `thread_id`** (cobertura comprovada 1635/1635).
3. **Menor unidade indexável = a linha** do `sessions.jsonl` (1 linha = 1 turno/evento).
4. O índice armazena **ponteiros, não conteúdo** (offset/linha/metadados leves — nunca o `text`).
5. A leitura futura usa **`seek(byte_offset)` + `readline`** apenas das linhas da conversa.
6. **Validar o `thread_id` da linha lida** antes de usar (defesa contra offset obsoleto).
7. **Não assumir faixa única contígua** por conversa — indexar por linha (uma thread pode ter a
   linha de `session_index` separada do bloco de turnos).

## Estratégia futura (sugerida — NÃO implementar neste ADR)
Tabela Rails futura sugerida: **`conversation_turn_refs`**. Campos **conceituais**:

| Campo | Papel |
|---|---|
| `conversation_id` | FK→`conversations` (resolução local) |
| `thread_id` | chave canônica de cruzamento com o arquivo |
| `line_no` | nº da linha no `sessions.jsonl` |
| `byte_offset` | posição para `seek` |
| `role` | projeção leve para listagem/ordenação |
| `timestamp` | projeção leve para ordenação |
| `source_fingerprint` | versão do arquivo a que o offset pertence |
| `indexed_at` | quando o ponteiro foi gerado |

## Fingerprint
- Persistir um **fingerprint do `sessions.jsonl`** (ex.: **size + mtime + hash parcial** de cabeça/cauda,
  ou equivalente).
- Usar o fingerprint para **detectar índice obsoleto** (arquivo regenerado pelo pipeline).
- **Reindexar quando o arquivo mudar**; nunca ler turnos com índice obsoleto.

## Segurança
- `text`, `tool_input` e demais payloads são **conteúdo não confiável**.
- **Renderização fica para a F5**; **sanitização** deve seguir o **ADR-012** (markdown server-side).
- **`tool_input` nunca** deve ser tratado como HTML confiável.
- **`raw_source_file`** (e paths embutidos) podem conter **PII** — caminhos com usuário devem ser
  **omitidos ou redigidos como `<USER>`** (padrão já usado na F3.3/ADR-020).
- Conversas com **`personal = true`** (ADR-013) devem ser respeitadas ao expor conteúdo (F5).

## Escopo negativo (o que este ADR NÃO autoriza)
- **Não** importar turnos para o banco agora.
- **Não** renderizar markdown nesta decisão.
- **Não** fazer **full-scan** do `sessions.jsonl` por request.
- **Não** usar os **shards** atuais como lookup direto por conversa (ADR-018: shard = arquivo-fonte).
- **Não** alterar importers.
- **Não** executar sync.
- **Não** implementar a F5 neste ADR.

## Alternativas rejeitadas
- **Full-scan do `sessions.jsonl` por request** — custo de IO repetido (229 MiB) e latência inaceitável.
- **Sidecar externo como solução principal** — menos auditável/transacional que uma tabela Rails.
- **Re-shard por `thread_id`** no lado Rails — custo de armazenamento (1635 arquivos) sem necessidade.
- **Usar os shards atuais como lookup direto por conversa** — refutado pelo ADR-018 (chave por
  arquivo-fonte; 1 shard com 1+ threads; 1 thread em 1+ shards; sem índice `thread_id→shard`).

## Consequências
### Positivas
- Abertura de conversa **bounded** (lê só as linhas da thread).
- **Evita full-scan** por request.
- **Evita persistir conteúdo sensível** no banco.
- **Prepara a F5** com uma fonte de turnos localizável, segura e auditável.
### Negativas / custos
- Exige um **builder/rebuilder** de índice futuro.
- Exige **verificação de fingerprint** (e reindex quando o arquivo muda).

## Critérios de aceite (para a futura fatia de implementação — fora deste ADR)
- Build em **uma passada streaming**, **sem OOM** em ~229 MiB; cobertura **1635/1635**; idempotente.
- Fingerprint persistido; índice obsoleto **detectado e reconstruído**; nunca ler com índice obsoleto.
- Abertura lazy lê **só** as linhas da conversa (sem full-scan), ordenadas por `timestamp`/`seq`.
- Leitura **binary/encoding-safe**; linha malformada → pula e marca `partial` (sem crash).
- **Sem render** nesta fatia; quando a F5 renderizar, **sanitização ADR-012** (payload XSS neutralizado,
  `tool_input` nunca HTML, `raw_source_file` redigido/omitido); `personal` respeitado.

## O que NÃO fazer
- Não calcular shard a partir de `thread_id` (ADR-018).
- Não importar turnos em massa para o banco.
- Não renderizar conteúdo sem sanitização (ADR-012).
- Não ler o arquivo inteiro a cada request.

## Relação com outros ADRs
- **Complementa o ADR-009** (turnos lazy) e o **ADR-018** (shards/turnos fora da F3) — define **como**
  localizar os turnos sob demanda.
- Relacionado ao **ADR-008** (consumo de `output/normalized/`), **ADR-012** (sanitização — F5) e
  **ADR-013** (conversas pessoais).
- Contrato de fronteira da F5 em [F5_CONTRACT_DECISIONS.md](../F5_CONTRACT_DECISIONS.md).
