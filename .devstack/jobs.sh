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

# PB-016a — sincronização COMPLETA pelo Omni (pipeline + importação).
#   OMNI_RUN_PIPELINE_INTERNALLY  liga a execução do pipeline pelo worker (default 0)
#   OMNI_PIPELINE_HOST_DIR        raiz do RepoB no host (montado :ro em /pipeline)
#   OMNI_PIPELINE_OUTPUT_HOST_DIR output do pipeline no host (montado :rw — única escrita)
# Mounts (fronteiras de escrita — item 4 da PB-016a):
#   /pipeline                 :ro  (código do RepoB; NUNCA escrito pelo job)
#   /pipeline/pipeline/output :rw  (raw/normalized/reports/state — única árvore gravável)
#   /normalized               :ro  (importação só lê)
RUN_PIPELINE="${OMNI_RUN_PIPELINE_INTERNALLY:-0}"
PIPELINE_HOST_DIR="${OMNI_PIPELINE_HOST_DIR:-/c/Sandbox/_omni/_origem/_repob}"
PIPELINE_OUTPUT_HOST_DIR="${OMNI_PIPELINE_OUTPUT_HOST_DIR:-/c/Sandbox/_omni/_origem/_repob/pipeline/output}"

docker network inspect "$NETWORK" >/dev/null 2>&1 || docker network create "$NETWORK"

# Monta o pipeline apenas quando a execução interna está habilitada.
PIPELINE_MOUNTS=()
if [ "$RUN_PIPELINE" = "1" ]; then
  PIPELINE_MOUNTS=(
    -v "${PIPELINE_HOST_DIR}:/pipeline:ro"
    -v "${PIPELINE_OUTPUT_HOST_DIR}:/pipeline/pipeline/output:rw"
  )
fi

docker rm -f omni_jobs >/dev/null 2>&1 || true
MSYS_NO_PATHCONV=1 docker run -d --name omni_jobs \
  --network "$NETWORK" \
  -e JOB_CONCURRENCY="${JOB_CONCURRENCY}" \
  -e OMNI_RUN_PIPELINE_INTERNALLY="${RUN_PIPELINE}" \
  -v "${APP_DIR}:/app" \
  -v omni_bundle:/usr/local/bundle \
  -v "${NORMALIZED_DIR}:/normalized:ro" \
  "${PIPELINE_MOUNTS[@]}" \
  -w /app "$IMAGE" bin/jobs

echo "omni_jobs no ar (SolidQueue worker, isolado do web)"
echo "  /normalized montado :ro de ${NORMALIZED_DIR}"
if [ "$RUN_PIPELINE" = "1" ]; then
  echo "  pipeline interno LIGADO:"
  echo "    /pipeline :ro de ${PIPELINE_HOST_DIR} (código read-only)"
  echo "    /pipeline/pipeline/output :rw de ${PIPELINE_OUTPUT_HOST_DIR} (única escrita)"
else
  echo "  pipeline interno DESLIGADO (só importa /normalized; export OMNI_RUN_PIPELINE_INTERNALLY=1 p/ ligar)"
fi
echo "  concorrência=${JOB_CONCURRENCY} · sem SOLID_QUEUE_IN_PUMA"
