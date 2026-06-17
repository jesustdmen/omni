# Corpus sintético de contrato — F3 (sync de conversas normalizadas)

> **100% sintético. Sem dados reais.** Criado do zero para caracterizar o **contrato** dos
> arquivos normalizados do RepoB e exercitar o futuro importer da F3.1. **Nada aqui é importado em
> produção** e **nenhuma migration/model/importer existe ainda** (F3.1 aguarda autorização).
> Decisões em [docs/F3_CONTRACT_DECISIONS.md](../../../docs/F3_CONTRACT_DECISIONS.md);
> turnos fora da F3 em [docs/adr/ADR-018-…](../../../docs/adr/ADR-018-addendum-adr-009-shards-turnos-lazy.md).

## Arquivos
| Arquivo | Papel |
|---|---|
| `summaries.jsonl` | 1 linha por `SessionSummary` → futura tabela `conversations` |
| `session_titles.json` | mapa `thread_id → título` (sobrescreve título da linha) |
| `workspace_maps.json` | mapa `workspace_hash → pasta` (stand-in sintético do `workspace.json` do ingest) |
| `tags.json` | tags globais (forma mínima do contrato) |
| `sessions.jsonl` | **apenas documental** (turnos) — **NÃO importar em massa na F3** (ADR-018) |

## O que `summaries.jsonl` cobre (4 linhas)
1. **Válida A** — `thread_id` estilo **UUID** (`11111111-…`), workspace **conhecido**, título **canônico via `session_titles.json`**.
2. **Válida B** — `thread_id` estilo **sha1/40-hex** (`a1b2c3…`), workspace **órfão**, sem entrada em `session_titles.json` → **fallback** para o título da própria linha.
3. **Válida C** — **mesmo `thread_id` da A** (duplicado): `last_ts` mais novo, contadores maiores, `first_ts` mais antigo, `files_changed` diferente → exercita **a regra de merge** (min `first_ts`, max `last_ts`, **max** dos contadores, **união** de `files_changed`, `workspace`/`source` da linha de maior `last_ts`, título canônico).
4. **Malformada** — JSON inválido → deve virar `error_lines` e a run concluir como `partial`.

→ **3 válidas + 1 malformada**, com **2 compartilhando `thread_id`** (A e C). Distintos válidos: **2** (A, B).

## Resultado esperado do futuro importer (F3.1)
- `lines_processed = 4`, `error_lines = 1` (linha 4), `skipped = 0`, status **`partial`**.
- `Conversation.count = 2` (A merge de 1+3; B).
- **A** após merge: `first_ts = 2026-01-10T08:55:00Z`, `last_ts = 2026-01-10T10:00:00Z`,
  `message_count = 9`, `user_turns = 4`, `assistant_turns = 5`, `tool_calls = 3`,
  `files_changed = ["a.rb","b.rb"]` (união), `title = "Título canônico de A (via session_titles)"`,
  `workspace_hash` e `source` da linha de maior `last_ts` (C).
- **B**: `title` = título da linha (fallback), `workspace_hash` = órfão (listável como órfão).
- `workspace_maps`: `wsknown…a1` resolvido; `wsorphan…b9` **órfão** (ausente do mapa).

> Datas/contadores são fixos e determinísticos para asserções estáveis nos testes da F3.1.
