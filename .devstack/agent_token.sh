#!/usr/bin/env bash
# Onda 0 — FONTE ÚNICA do contrato do token do pipeline-agent (dev local).
#
# Regra: NÃO versionar token fixo. Este helper é `source`-ado por agent.sh,
# up.sh e jobs.sh — eles NÃO resolvem o token por conta própria, só consomem o
# resultado. Garante que o AGENTE (host) e o RAILS/worker (containers) usem
# EXATAMENTE o mesmo valor, sem hardcode e sem imprimir o token.
#
# Variáveis do contrato:
#   OMNI_AGENT_TOKEN           — canônica (lida pelo agente Python)
#   OMNI_PIPELINE_AGENT_TOKEN  — alias de compatibilidade (lida pelo Rails/worker)
#
# Precedência/regras:
#   1) se AMBAS definidas com valores DIFERENTES  → falha imediata (sem exibir);
#   2) se alguma explicitamente definida for FRACA → falha imediata (não substitui);
#   3) se só uma (forte) estiver definida          → usa seu valor para as duas;
#   4) se nenhuma estiver definida                 → reutiliza .devstack/.agent_token
#      ou gera token aleatório (32 bytes), persiste (git-ignored) e usa.
#   Ao final EXPORTA OMNI_AGENT_TOKEN e OMNI_PIPELINE_AGENT_TOKEN com o MESMO valor.
#
# Uso normal:  . .devstack/agent_token.sh   (exporta as duas variáveis)
# `AGENT_TOKEN_STRICT_RETURN=1` faz o helper `return`/`exit` com código != 0 em vez
# de encerrar o shell interativo — usado pelos testes.
_MIN_TOKEN_LEN=16
_TOKEN_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.agent_token"

_agent_token_fail() {
  echo "[devstack] ERRO: $1" >&2
  if [ "${AGENT_TOKEN_STRICT_RETURN:-0}" = "1" ]; then
    return 1 2>/dev/null || exit 1
  fi
  exit 1
}

_gen_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
  elif command -v python >/dev/null 2>&1; then
    python -c "import secrets; print(secrets.token_hex(32))"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "import secrets; print(secrets.token_hex(32))"
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
  fi
}

resolve_agent_token() {
  local canon="${OMNI_AGENT_TOKEN:-}"
  local alias_="${OMNI_PIPELINE_AGENT_TOKEN:-}"
  local resolved=""

  # 1) ambas definidas e divergentes → falha (nunca exibir os valores).
  if [ -n "$canon" ] && [ -n "$alias_" ] && [ "$canon" != "$alias_" ]; then
    _agent_token_fail "OMNI_AGENT_TOKEN e OMNI_PIPELINE_AGENT_TOKEN estão definidas com valores DIFERENTES. Defina apenas uma, ou as duas com o mesmo valor." || return 1
  fi

  # 2) variável explicitamente definida e fraca → falha (não substitui em silêncio).
  if [ -n "$canon" ] && [ "${#canon}" -lt "$_MIN_TOKEN_LEN" ]; then
    _agent_token_fail "OMNI_AGENT_TOKEN definido é fraco (< ${_MIN_TOKEN_LEN} caracteres)." || return 1
  fi
  if [ -n "$alias_" ] && [ "${#alias_}" -lt "$_MIN_TOKEN_LEN" ]; then
    _agent_token_fail "OMNI_PIPELINE_AGENT_TOKEN definido é fraco (< ${_MIN_TOKEN_LEN} caracteres)." || return 1
  fi

  # 3) só uma (forte) definida (ou as duas iguais e fortes) → usa seu valor.
  if [ -n "$canon" ]; then
    resolved="$canon"
  elif [ -n "$alias_" ]; then
    resolved="$alias_"
  fi

  # 4) nenhuma definida → reutiliza o arquivo local ou gera e persiste.
  if [ -z "$resolved" ]; then
    if [ -f "$_TOKEN_FILE" ]; then
      local tok
      tok="$(tr -d ' \r\n' < "$_TOKEN_FILE")"
      if [ "${#tok}" -ge "$_MIN_TOKEN_LEN" ]; then
        resolved="$tok"
      fi
    fi
  fi
  if [ -z "$resolved" ]; then
    resolved="$(_gen_token)"
    ( umask 177; printf '%s\n' "$resolved" > "$_TOKEN_FILE" )
    chmod 600 "$_TOKEN_FILE" 2>/dev/null || true
    echo "[devstack] token do pipeline-agent gerado e salvo em .devstack/.agent_token (git-ignored; valor não exibido)."
  fi

  # Exporta AS DUAS com exatamente o mesmo valor (fonte única do contrato).
  export OMNI_AGENT_TOKEN="$resolved"
  export OMNI_PIPELINE_AGENT_TOKEN="$resolved"
}

resolve_agent_token
