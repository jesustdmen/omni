# ADR-020 — Exceção read-only para `workspaceStorage` (resolução de folders)

## Status
Aceito — 2026-06-17 (Fase 3, F3.3). Complementa o **ADR-008** (consumo de `output/normalized/`).

## Contexto
- A F3.2 importou conversas (metadados) consumindo **apenas** `summaries.jsonl` e `session_titles.json`
  de `output/normalized/` (ADR-007/008).
- A F3.3 precisou resolver **`workspace_maps.folder`** (`workspace_hash → folder` legível).
- Esse dado **não existe consolidado** em `output/normalized/` (não há `workspace_maps.json`).
- O dado existe, por workspace, em
  `output/raw/snapshot_20260616_112333/workspaceStorage/<hash>/workspace.json`
  (ex.: `{ "folder": "file:///c%3A/AtivaLocal" }`), onde o nome da pasta é o `workspace_hash`.

## Decisão
Autorizar uma **exceção controlada** ao princípio "consumir somente `output/normalized/`":
- Ler **somente leitura (`:ro`)** a área `workspaceStorage`, **somente** os arquivos `workspace.json`,
  **somente** para resolver `workspace_hash → folder`.
- Usar **somente o snapshot explicitamente autorizado** (`snapshot_20260616_112333`).
- **Não** ler conversas, turnos, `sessions.jsonl`, shards; **não** executar o pipeline do RepoB.

## Alternativas consideradas
- **Esperar o RepoB emitir `workspace_maps.json` normalizado** — correto perante ADR-008, mas exige
  alterar/rodar o RepoB (fora de escopo; `_origem/_repob` é somente leitura).
- **Deixar todos os workspaces órfãos** — perde a resolução de pasta útil para validação/UI futura.

## Restrições
- Origem sempre montada **`:ro`**; **não** alterar `_origem/_repob`.
- **Não** executar pipeline.
- **Atualizar apenas** `WorkspaceMap` existentes (vistos em conversas); **não criar** workspaces extras.
- **Redigir usuário/home** no `folder` antes de persistir (`/Users/<nome>` → `/Users/<USER>`).

## Consequências positivas
- Reduz workspaces órfãos (na execução real: 86 → 3).
- Melhora a validação visual futura (pastas legíveis).

## Consequências negativas
- Introduz uma exceção controlada à fronteira "normalized-only".

## Reversibilidade
- Se futuramente o RepoB emitir um `workspace_maps.json` em `output/normalized/`, esta exceção pode ser
  **removida** e a resolução passa a consumir o normalizado (novo ADR substituindo este).

## Critérios de aceite
- Leitura `:ro`; origem inalterada; só `workspace.json`; sem conversas/turnos/shards/pipeline.
- Atualiza só `workspace_maps` existentes; usuário redigido; idempotente.

## O que NÃO fazer
- Não ler `sessions.jsonl`/shards/conversas a partir de `raw/`.
- Não criar `WorkspaceMap` para workspaces sem conversa importada.
- Não persistir o nome real do usuário local.

## Relação com outros ADRs
- **Complementa o ADR-008** (consumo de `output/normalized/`) e o **ADR-007** (pipeline externo).
- Detalhes operacionais e resultado em [F3_CONTRACT_DECISIONS.md](../F3_CONTRACT_DECISIONS.md) (§6).
