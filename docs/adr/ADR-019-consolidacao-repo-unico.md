# ADR-019 — Consolidação em repositório único (`app/`)

## Status
Aceito — 2026-06-17 (Fase 3, pré-F3.0).

## Contexto
Até 2026-06-17 o projeto tinha **dois repositórios Git**:
- `c:\Sandbox\_omni\app` — a aplicação Rails (produto), 7 commits (M1 → F2.5), com CI (`.github/workflows/ci.yml`).
- `c:\Sandbox\_omni` (raiz) — apenas governança, versionando só `docs/` (7 docs + 17 ADRs).

Nenhum dos dois tinha remoto configurado. A aplicação real roda apenas em `app/`. Manter dois repositórios independentes adicionava overhead (dois remotos, duas CIs, dois fluxos de push) sem benefício atual, e dificultava manter docs e código na mesma fonte de verdade.

## Decisão
Consolidar em **um único repositório principal: `app/`**.
- A governança passa a viver **dentro do app**, em **`app/docs/`** (ADRs, roadmap, status, matriz, log, plano).
- A raiz `c:\Sandbox\_omni` deixa de ser repositório de produto: vira **pasta local de trabalho/histórico**.
- O `.git` da raiz **é mantido como arquivo histórico** (não apagado agora) e **não recebe mais commits**.
- `_origem/_repoa`, `_origem/_repob` e `_mockup/` permanecem **fora** do repositório do app (irmãos de `app/`), **somente leitura** e **não versionados**.
- O `.gitignore` do app é reforçado com proteções defensivas contra dumps/snapshots (reaproveitando a intenção do `.gitignore` da raiz — higiene SEC-DUMP).
- F3.0/F3.1 e as demais fases passam a ser **documentadas dentro de `app/docs/`**.

## Alternativas consideradas
- **Manter dois repositórios** — mais overhead operacional; docs separados do código; dois remotos/CIs.
- **Preservar o histórico granular dos docs via `git subtree`/enxerto** — possível, mas desnecessário agora: o histórico de docs é pequeno e fica retido no `.git` da raiz (arquivo). Pode ser feito no futuro a partir desse `.git` preservado.

## Consequências positivas
- Uma fonte de verdade (código + governança); um remoto; uma CI.
- Fluxo de entrega mais simples (um commit/push por entrega cobre código e docs).
- Referências (`_origem/`, `_mockup/`) seguem isoladas e intocadas.

## Consequências negativas
- O histórico granular de commits de docs fica no `.git` da raiz (arquivo), não na linha principal do app (incorporado como estado atual num único commit).
- Documentos que descreviam a topologia de dois repositórios precisam ser corrigidos (feito: `CONSTRAINTS.md`, `PROJECT_STATUS.md`, índice de ADRs).

## Riscos
- **Divergência** se os docs da raiz continuarem sendo editados após a cópia → mitigação: raiz congelada; toda edição futura em `app/docs/`.
- **Contradição de topologia** em docs antigos → mitigado neste mesmo commit.

## Critérios de aceite
- `app/docs/` existe com os 24 documentos; topologia antiga corrigida nos docs; ADR-019 registrado no índice.
- Testes/lint/segurança do app verdes após a incorporação.
- Sem push/remoto até autorização explícita das URLs.

## O que NÃO fazer
- Não apagar o `.git` da raiz agora.
- Não versionar `_origem/`/`_mockup/` dentro do app.
- Não fazer push nem configurar remoto sem autorização explícita das URLs.
