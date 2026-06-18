#!/usr/bin/env bash
# F5.1.2 — sobe o container de dev `omni_web` (Fundação Rails) de forma reprodutível.
#
# Persiste o mount READ-ONLY de `output/normalized/` (do RepoB) em /normalized, exigido
# pelo lazy-load de turnos (ADR-021): sem ele, ConversationTurns::LazyLoader retorna :stale.
# NÃO copia nem versiona sessions.jsonl — apenas monta a fonte em modo somente-leitura (ADR-008).
#
# Uso (Git Bash / WSL):  bash .devstack/up.sh
# Variáveis overridáveis por ambiente (defaults para a máquina de dev atual):
#   OMNI_IMAGE           imagem dev (default: omni-rails-dev)
#   OMNI_NET             rede docker (default: omni_net)
#   OMNI_PORT            porta no host (default: 3000)
#   OMNI_APP_DIR         caminho do app no host (default: /c/Sandbox/_omni/app)
#   OMNI_NORMALIZED_DIR  caminho de output/normalized no host (montado :ro)
set -euo pipefail

IMAGE="${OMNI_IMAGE:-omni-rails-dev}"
NETWORK="${OMNI_NET:-omni_net}"
PORT="${OMNI_PORT:-3000}"
APP_DIR="${OMNI_APP_DIR:-/c/Sandbox/_omni/app}"
NORMALIZED_DIR="${OMNI_NORMALIZED_DIR:-/c/Sandbox/_omni/_origem/_repob/pipeline/output/normalized}"

# Rede (idempotente).
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

# Remove server.pid órfão (o app é bind-mount; o pid sobrevive ao container).
rm -f "$APP_DIR/tmp/pids/server.pid" 2>/dev/null || true

# Recria o container (idempotente).
docker rm -f omni_web >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run -d --name omni_web \
  --network "$NETWORK" -p "${PORT}:3000" \
  -v "${APP_DIR}:/app" \
  -v omni_bundle:/usr/local/bundle \
  -v "${NORMALIZED_DIR}:/normalized:ro" \
  -w /app "$IMAGE" bin/rails server -b 0.0.0.0 -p 3000

echo "omni_web no ar em http://localhost:${PORT}"
echo "  /normalized montado :ro de ${NORMALIZED_DIR}"
echo "  (turnos lazy-load — ADR-021 — dependem deste mount; ele é read-only)"
