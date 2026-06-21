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
NORMALIZED_DIR="${OMNI_NORMALIZED_DIR:-/c/Sandbox/_omni/_origem/_repob/pipeline/output/normalized}"
JOB_CONCURRENCY="${JOB_CONCURRENCY:-1}"

docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

docker rm -f omni_jobs >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run -d --name omni_jobs \
  --network "$NETWORK" \
  -e JOB_CONCURRENCY="${JOB_CONCURRENCY}" \
  -v "${APP_DIR}:/app" \
  -v omni_bundle:/usr/local/bundle \
  -v "${NORMALIZED_DIR}:/normalized:ro" \
  -w /app "$IMAGE" bin/jobs

echo "omni_jobs no ar (SolidQueue worker, isolado do web)"
echo "  /normalized montado :ro de ${NORMALIZED_DIR}"
echo "  concorrência=${JOB_CONCURRENCY} · sem SOLID_QUEUE_IN_PUMA"
