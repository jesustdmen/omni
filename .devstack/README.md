# .devstack — toolchain de desenvolvimento (não é deploy)

Ambiente de dev da Fundação Rails. **Não** é o `Dockerfile` de produção (esse fica na raiz do app, usado por Kamal).

## Componentes
- **`Dockerfile`** — imagem dev `omni-rails-dev` (Ruby 3.3 + `libpq`/`postgresql-client`). Gems vivem no volume nomeado `omni_bundle`.
- **`up.sh`** — sobe o container `omni_web` de forma reprodutível, **com o mount read-only de `/normalized`** (ver abaixo). Chama `jobs.sh` e `agent.sh` (a menos que `OMNI_SKIP_JOBS=1` / `OMNI_SKIP_AGENT=1`).
- **`jobs.sh`** — sobe o worker `omni_jobs` (SolidQueue, isolado do web).
- **`agent.sh`** — sobe o **agente de coleta NO HOST** (Windows nativo) em `:8765`, apontando para o pipeline **NATIVO** `app/pipeline/run_collect.py` (F7.7), com auto-restart.

## Subir o ambiente
Pré-requisitos (uma vez): rede `omni_net`, container `omni_db` (Postgres 16) e a imagem `omni-rails-dev` construída; gems instaladas no volume `omni_bundle`.

```bash
bash .devstack/up.sh
# http://localhost:3000
```

## Coleta nativa LIGADA por padrão no local (F7.7)
No ambiente de dev/local o devstack sobe **operacional**: `up.sh`/`jobs.sh` usam **`OMNI_RUN_PIPELINE_INTERNALLY=1` por padrão**, então web e worker rodam com a **coleta pelo Omni ligada** e `up.sh` também inicia o **agente no host** (`agent.sh`) e o **worker** (`jobs.sh`). Em `/sync_runs` isso faz "Sincronizar agora" representar **coleta + importação** (e, com o agente no ar, exibe o agente **online**); a opção "Importar arquivos disponíveis" continua existindo.

- **Desligar a coleta no local:** `OMNI_RUN_PIPELINE_INTERNALLY=0 bash .devstack/up.sh` (volta ao modo "só importa `/normalized`").
- **ENV repassada a web/jobs:** `OMNI_RUN_PIPELINE_INTERNALLY`, `OMNI_PIPELINE_AGENT_URL`, `OMNI_PIPELINE_AGENT_TOKEN`, `OMNI_PIPELINE_TIMEOUT`; o mount `/normalized:ro` vem de `app/pipeline/output/normalized` (`OMNI_NORMALIZED_DIR`). Dentro do container o app lê de **`/normalized`** (`config.x.normalized_dir`, default).
- **Default de runtime do Rails segue `false`** (`config/application.rb`): **produção e testes/CI NÃO coletam por acidente** — quem liga a coleta é este devstack. A suíte de testes injeta um runner falso e nunca executa o pipeline real.
- **Produção** ainda depende da topologia F7.2–F7.6 (worker no deploy, Kamal, entrega do volume `/normalized`, onde o host roda a coleta).

## Por que o mount `/normalized:ro` é necessário
O lazy-load de turnos (**ADR-021**) não importa o conteúdo das conversas para o banco — ele guarda apenas **ponteiros (offsets)** e lê as linhas sob demanda diretamente de `output/normalized/sessions.jsonl`. **F7.7:** essa saída agora é gerada pelo **pipeline NATIVO do Omni** (`app/pipeline/output/normalized/`), não mais pelo RepoB. O `turn_source.source_file` aponta para **`/normalized/sessions.jsonl`**.

Se o `omni_web` for iniciado **sem** esse mount, `ConversationTurns::LazyLoader` não encontra o arquivo e retorna **`:stale`** (a tela de conversa mostra "índice desatualizado" e não renderiza turnos). O `up.sh` persiste esse mount, evitando a regressão.

- O mount é **somente-leitura** (`:ro`) — consistente com o ADR-008 (consumir `output/normalized/`).
- **O CÓDIGO do pipeline vive no app** (`app/pipeline/`, F7.7); a **saída gerada** (`app/pipeline/output/`, incl. `sessions.jsonl` ~250 MB) **não** é versionada (`.gitignore`).
- Caminhos são overridáveis por env (`OMNI_NORMALIZED_DIR`, `OMNI_APP_DIR`, `OMNI_PORT`, `OMNI_NET`, `OMNI_IMAGE`).

## Reindexar turnos (quando o `sessions.jsonl` mudar)
```bash
MSYS_NO_PATHCONV=1 docker run --rm --network omni_net \
  -v "/c/Sandbox/_omni/app:/app" -v omni_bundle:/usr/local/bundle \
  -v "/c/Sandbox/_omni/app/pipeline/output/normalized:/normalized:ro" \
  -w /app omni-rails-dev bash -c "bin/rails 'sync:turn_refs[/normalized/sessions.jsonl]'"
```
