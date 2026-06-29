#!/usr/bin/env bash
# PB-016a — sobe o AGENTE de pipeline do Omni NO HOST (Windows), com auto-restart.
#
# O pipeline (RepoB) é Windows-nativo (lê %APPDATA%/.codex/.claude e exige APPDATA);
# por isso roda no host, não no container. O Omni (container) dispara este agente
# por HTTP. Este script mantém o agente vivo (reinicia se cair) — assim, do ponto
# de vista do clique "Sincronizar agora", o agente está sempre disponível.
#
# Uso (Git Bash):  bash .devstack/agent.sh        # foreground (com auto-restart)
#                  bash .devstack/agent.sh &      # background
# Variáveis (defaults para a máquina de dev):
#   OMNI_AGENT_HOST / OMNI_AGENT_PORT / OMNI_AGENT_TOKEN
#   OMNI_PIPELINE_DIR / OMNI_PIPELINE_PYTHON / OMNI_PIPELINE_TIMEOUT
#   OMNI_AGENT_PYTHON  python do host p/ rodar o AGENTE (default resolve abaixo)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
AGENT_PY="${HERE}/../script/pipeline_agent.py"

export OMNI_AGENT_HOST="${OMNI_AGENT_HOST:-0.0.0.0}"
export OMNI_AGENT_PORT="${OMNI_AGENT_PORT:-8765}"
export OMNI_AGENT_TOKEN="${OMNI_AGENT_TOKEN:-omni-dev-agent}"
export OMNI_PIPELINE_DIR="${OMNI_PIPELINE_DIR:-/c/Sandbox/_omni/app/pipeline}"
export OMNI_PIPELINE_TIMEOUT="${OMNI_PIPELINE_TIMEOUT:-1800}"

# Python do HOST p/ rodar o agente (não o do pipeline; o agente decide o do pipeline).
resolve_python() {
  if [ -n "${OMNI_AGENT_PYTHON:-}" ]; then echo "$OMNI_AGENT_PYTHON"; return; fi
  for c in python python3 py; do
    if command -v "$c" >/dev/null 2>&1; then echo "$c"; return; fi
  done
  echo "python"
}
PY="$(resolve_python)"

# Já está no ar? (idempotente — não sobe um segundo)
if curl -s --max-time 3 "http://127.0.0.1:${OMNI_AGENT_PORT}/health" >/dev/null 2>&1; then
  echo "pipeline-agent já está no ar em :${OMNI_AGENT_PORT}"
  exit 0
fi

echo "iniciando pipeline-agent (host) em :${OMNI_AGENT_PORT} com ${PY}"
# Loop de auto-restart: se o agente cair, sobe de novo após 2s (até Ctrl+C).
while true; do
  "$PY" "$AGENT_PY"
  code=$?
  echo "[agent] saiu (code=$code); reiniciando em 2s… (Ctrl+C para parar)"
  sleep 2
done
