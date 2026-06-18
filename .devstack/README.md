# .devstack — toolchain de desenvolvimento (não é deploy)

Ambiente de dev da Fundação Rails. **Não** é o `Dockerfile` de produção (esse fica na raiz do app, usado por Kamal).

## Componentes
- **`Dockerfile`** — imagem dev `omni-rails-dev` (Ruby 3.3 + `libpq`/`postgresql-client`). Gems vivem no volume nomeado `omni_bundle`.
- **`up.sh`** — sobe o container `omni_web` de forma reprodutível, **com o mount read-only de `/normalized`** (ver abaixo).

## Subir o ambiente
Pré-requisitos (uma vez): rede `omni_net`, container `omni_db` (Postgres 16) e a imagem `omni-rails-dev` construída; gems instaladas no volume `omni_bundle`.

```bash
bash .devstack/up.sh
# http://localhost:3000
```

## Por que o mount `/normalized:ro` é necessário
O lazy-load de turnos (**ADR-021**) não importa o conteúdo das conversas para o banco — ele guarda apenas **ponteiros (offsets)** e lê as linhas sob demanda diretamente de `output/normalized/sessions.jsonl` (do RepoB). O `turn_source.source_file` aponta para **`/normalized/sessions.jsonl`**.

Se o `omni_web` for iniciado **sem** esse mount, `ConversationTurns::LazyLoader` não encontra o arquivo e retorna **`:stale`** (a tela de conversa mostra "índice desatualizado" e não renderiza turnos). O `up.sh` persiste esse mount, evitando a regressão.

- O mount é **somente-leitura** (`:ro`) — consistente com o ADR-008 (consumir `output/normalized/`).
- **Nada é copiado para dentro do app**; `sessions.jsonl` **não** é versionado (vive em `_origem/`, fora do repo).
- Caminhos são overridáveis por env (`OMNI_NORMALIZED_DIR`, `OMNI_APP_DIR`, `OMNI_PORT`, `OMNI_NET`, `OMNI_IMAGE`).

## Reindexar turnos (quando o `sessions.jsonl` mudar)
```bash
MSYS_NO_PATHCONV=1 docker run --rm --network omni_net \
  -v "/c/Sandbox/_omni/app:/app" -v omni_bundle:/usr/local/bundle \
  -v "/c/Sandbox/_omni/_origem/_repob/pipeline/output/normalized:/normalized:ro" \
  -w /app omni-rails-dev bash -c "bin/rails 'sync:turn_refs[/normalized/sessions.jsonl]'"
```
