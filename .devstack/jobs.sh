#!/usr/bin/env bash
# PB-015 — sobe o container de WORKER de jobs `omni_jobs`, ISOLADO do web.
#
# Roda o SolidQueue supervisor (bin/jobs) num processo separado do Puma (sem
# SOLID_QUEUE_IN_PUMA), para não competir por threads do web e espelhar a
# topologia de produção (web ≠ worker). Monta /normalized :ro igual ao web —
# o job de sincronização (PB-015) lê apenas dessa fonte fixa.
#
# Uso (Git Bash / WSL):  bash .devstack/jobs.sh
# Variáveis (mesmos defaults do up.sh):
#   OMNI_IMAGE / OMNI_NET / OMNI_APP_DIR / OMNI_NORMALIZED_DIR / JOB_CONCURRENCY
set -euo pipefail

IMAGE="${OMNI_IMAGE:-omni-rails-dev}"
NETWORK="${OMNI_NET:-omni_net}"
APP_DIR="${OMNI_APP_DIR:-/c/Sandbox/_omni/app}"
NORMALIZED_DIR="${OMNI_NORMALIZED_DIR:-/c/Sandbox/_omni/app/pipeline/output/normalized}"
JOB_CONCURRENCY="${JOB_CONCURRENCY:-1}"

# PB-016a — sincronização COMPLETA pelo Omni (pipeline + importação).
# O pipeline (RepoB) é Windows-nativo e roda NO HOST, via AGENTE (script/pipeline_agent.py);
# o worker NÃO executa Python nem monta o pipeline — só dispara o agente por HTTP e
# importa /normalized. Por isso aqui só passamos a flag + URL/token do agente.
#   OMNI_RUN_PIPELINE_INTERNALLY  liga a coleta pelo Omni (default 0; o agente faz a coleta)
#   OMNI_PIPELINE_AGENT_URL       URL do agente no host (default host.docker.internal:8765)
#   OMNI_PIPELINE_AGENT_TOKEN     token compartilhado com o agente
RUN_PIPELINE="${OMNI_RUN_PIPELINE_INTERNALLY:-0}"
AGENT_URL="${OMNI_PIPELINE_AGENT_URL:-http://host.docker.internal:8765}"
AGENT_TOKEN="${OMNI_PIPELINE_AGENT_TOKEN:-omni-dev-agent}"

docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

docker rm -f omni_jobs >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run -d --name omni_jobs \
  --network "$NETWORK" \
  -e JOB_CONCURRENCY="${JOB_CONCURRENCY}" \
  -e OMNI_RUN_PIPELINE_INTERNALLY="${RUN_PIPELINE}" \
  -e OMNI_PIPELINE_AGENT_URL="${AGENT_URL}" \
  -e OMNI_PIPELINE_AGENT_TOKEN="${AGENT_TOKEN}" \
  -v "${APP_DIR}:/app" \
  -v omni_bundle:/usr/local/bundle \
  -v "${NORMALIZED_DIR}:/normalized:ro" \
  -w /app "$IMAGE" bin/jobs

echo "omni_jobs no ar (SolidQueue worker, isolado do web)"
echo "  /normalized montado :ro de ${NORMALIZED_DIR}"
if [ "$RUN_PIPELINE" = "1" ]; then
  echo "  coleta LIGADA: dispara o agente no host em ${AGENT_URL} (o worker não roda Python)"
else
  echo "  coleta DESLIGADA (só importa /normalized; export OMNI_RUN_PIPELINE_INTERNALLY=1 p/ ligar)"
fi
echo "  concorrência=${JOB_CONCURRENCY} · sem SOLID_QUEUE_IN_PUMA"
