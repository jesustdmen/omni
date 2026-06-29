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
NORMALIZED_DIR="${OMNI_NORMALIZED_DIR:-/c/Sandbox/_omni/app/pipeline/output/normalized}"

# Rede (idempotente).
docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

# Remove server.pid órfão (o app é bind-mount; o pid sobrevive ao container).
rm -f "$APP_DIR/tmp/pids/server.pid" 2>/dev/null || true

# PB-016a — flag da coleta + URL/token do agente (a UI reflete o estado; o web não
# roda Python). Mesmos defaults do worker/agente.
RUN_PIPELINE="${OMNI_RUN_PIPELINE_INTERNALLY:-0}"
AGENT_URL="${OMNI_PIPELINE_AGENT_URL:-http://host.docker.internal:8765}"
AGENT_TOKEN="${OMNI_PIPELINE_AGENT_TOKEN:-omni-dev-agent}"

# Recria o container (idempotente).
docker rm -f omni_web >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run -d --name omni_web \
  --network "$NETWORK" -p "${PORT}:3000" \
  -e OMNI_RUN_PIPELINE_INTERNALLY="${RUN_PIPELINE}" \
  -e OMNI_PIPELINE_AGENT_URL="${AGENT_URL}" \
  -e OMNI_PIPELINE_AGENT_TOKEN="${AGENT_TOKEN}" \
  -v "${APP_DIR}:/app" \
  -v omni_bundle:/usr/local/bundle \
  -v "${NORMALIZED_DIR}:/normalized:ro" \
  -w /app "$IMAGE" bin/rails server -b 0.0.0.0 -p 3000

echo "omni_web no ar em http://localhost:${PORT}"
echo "  /normalized montado :ro de ${NORMALIZED_DIR}"
echo "  (turnos lazy-load — ADR-021 — dependem deste mount; ele é read-only)"

# PB-015 — sobe também o worker de jobs isolado (a menos que OMNI_SKIP_JOBS=1).
if [ "${OMNI_SKIP_JOBS:-0}" != "1" ]; then
  bash "$(dirname "$0")/jobs.sh"
else
  echo "  (omni_jobs não iniciado — OMNI_SKIP_JOBS=1)"
fi

# PB-016a — sobe o AGENTE de pipeline NO HOST (coleta roda no Windows nativo),
# com auto-restart, a menos que OMNI_SKIP_AGENT=1. Em background; idempotente.
if [ "${OMNI_SKIP_AGENT:-0}" != "1" ]; then
  ( bash "$(dirname "$0")/agent.sh" >/tmp/omni_pipeline_agent.log 2>&1 & )
  echo "  pipeline-agent (host) iniciando em :${OMNI_AGENT_PORT:-8765} (log: /tmp/omni_pipeline_agent.log)"
else
  echo "  (pipeline-agent não iniciado — OMNI_SKIP_AGENT=1)"
fi
