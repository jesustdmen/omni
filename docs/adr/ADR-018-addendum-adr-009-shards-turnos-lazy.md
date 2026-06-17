# ADR-018 — Addendum ao ADR-009 (shards e turnos lazy)

## Status
Aceito — 2026-06-17 (Fase 3, F3.0). Complementa o **ADR-009** (não o substitui).

## Contexto
O ADR-009 ("Turnos lazy/sob demanda") assumia, como validação futura, o mapeamento
**`thread_id → shards/messages/<sha1>`** — i.e., que o arquivo de shard de uma conversa
poderia ser localizado calculando o `sha1` do `thread_id`.

Na F3.0 essa hipótese foi **verificada empiricamente no RepoB** (referência, somente leitura) e **refutada**:

- Exemplo: o shard `shards/messages/004af3c44ff2bf9df6c5b0d5bd8188d9b0c9fc98.jsonl` contém
  apenas a thread `430a89e1db18f8ba53b91b88d6d9997d05036cfe`, mas
  `sha1("430a89e1…") = 7381ee4a…` ≠ `004af3c4…`.
- A regra real (em `pipeline/02_normalize/normalize.py`) é:
  `shard_key = sha1("v" + _SHARD_SCHEMA_VERSION + ":" + file_type + ":" + source_path)`,
  com `_SHARD_SCHEMA_VERSION = "4"`.
- Ou seja, **o shard é derivado do arquivo-fonte bruto + tipo + versão do schema de shard**,
  **não do `thread_id`**. Um shard corresponde a uma fonte, podendo conter 1+ threads, e uma
  thread pode estar espalhada por mais de um shard.
- **Não existe** índice `thread_id → shard` em `output/normalized/` (sem arquivo de index/manifest/map).

## Decisão
1. A regra `thread_id → shards/messages/<sha1>` é **inválida** e **não será usada**.
2. **A F3 não importará turnos.** `sessions.jsonl` e `shards/messages/` ficam **fora da F3**.
3. O **lazy-load de turnos** (consumo sob demanda) será **decidido antes da F5**, em novo ADR/registro próprio.
4. **Estratégia provável futura** (a confirmar, **sem implementação agora**): construir um
   **índice `thread_id → offset(s)/shard(s)`** durante o sync (varrendo `sessions.jsonl` uma vez)
   e usá-lo para localizar os turnos sob demanda. Alternativas mantidas em aberto: índice por offset
   em `sessions.jsonl`; re-shard por `thread_id` no lado Rails.
5. **A F3.1 foca exclusivamente** em: `summaries.jsonl`, `session_titles.json`, `workspace_maps`,
   `sync_runs` e `sync_run_items`.

## Alternativas consideradas
- **Assumir o mapeamento `sha1(thread_id)`** — refutado pelos fatos acima.
- **Construir o índice de turnos já na F3** — fora do escopo MVP da F3; adia complexidade desnecessária
  antes da UI de conversa (F5).
- **Re-shardar por `thread_id` no Rails agora** — custo/armazenamento sem necessidade nesta fase.

## Consequências positivas
- Desbloqueia a F3 (metadados de conversa) sem depender de um mapeamento inexistente.
- Evita dívida técnica prematura no carregamento de turnos.

## Consequências negativas
- O carregamento de turnos fica pendente de decisão e implementação (F5).

## Riscos
- O `_SHARD_SCHEMA_VERSION` do RepoB pode mudar (hoje "4"); qualquer estratégia futura de turnos
  deve tratar a versão de contrato explicitamente (ver [F3_CONTRACT_DECISIONS.md](../F3_CONTRACT_DECISIONS.md)).

## Critérios de aceite
- F3/F3.1 não tocam em `sessions.jsonl`/`shards/messages`.
- Documentação reflete o mapeamento real e o adiamento dos turnos.

## O que NÃO fazer
- Não calcular shard a partir de `thread_id`.
- Não importar turnos em massa na F3.
- Não implementar lazy-load de turnos agora.

## Relação com outros ADRs
- **Complementa o ADR-009** (turnos lazy) — corrige a premissa de mapeamento.
- Relacionado ao **ADR-008** (consumo de `output/normalized/`) e **ADR-007** (pipeline externo).
