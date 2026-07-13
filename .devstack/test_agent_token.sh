#!/usr/bin/env bash
# Onda 0 — testes isolados do contrato de token (.devstack/agent_token.sh).
# Não sobe agente/containers, não aciona pipeline/sync. Só exercita o helper.
#
# Executar:  bash .devstack/test_agent_token.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
HELPER="${HERE}/agent_token.sh"
STRONG="t0ken-forte-de-teste-0123456789abcdef"   # 38 chars
STRONG2="OUTRO-t0ken-forte-de-teste-abcdef0123"   # 37 chars, != STRONG
WEAK="curto"
pass=0; fail=0

# Roda o helper num subshell isolado, com as variáveis do cenário. Ecoa
# "OK|<agent>|<alias>" em sucesso; em falha o helper faz `exit 1` e o subshell
# encerra antes do echo (capturamos pelo código de saída).
run() { # $1 = comando que define/limpa as vars do cenário
  (
    unset OMNI_AGENT_TOKEN OMNI_PIPELINE_AGENT_TOKEN
    eval "$1"
    . "$HELPER" >/tmp/agttok_out 2>/tmp/agttok_err || exit 1
    echo "OK|${OMNI_AGENT_TOKEN:-}|${OMNI_PIPELINE_AGENT_TOKEN:-}"
  )
}

check() { # $1 desc, $2 esperado(pass|fail), $3 saída, $4 rc
  local desc="$1" want="$2" out="$3" rc="$4"
  if [ "$want" = "pass" ] && [ "$rc" -eq 0 ] && [[ "$out" == OK\|* ]]; then
    local a b; a="${out#OK|}"; b="${a#*|}"; a="${a%%|*}"
    if [ -n "$a" ] && [ "$a" = "$b" ]; then
      echo "ok   — $desc (as duas variáveis iguais e não-vazias)"; pass=$((pass+1)); return
    fi
    echo "FAIL — $desc (esperava as duas iguais/não-vazias; got a='$a' b='$b')"; fail=$((fail+1)); return
  fi
  if [ "$want" = "fail" ] && [ "$rc" -ne 0 ]; then
    echo "ok   — $desc (falhou como esperado)"; pass=$((pass+1)); return
  fi
  echo "FAIL — $desc (want=$want rc=$rc out='$out')"; fail=$((fail+1))
}

# (a) só OMNI_AGENT_TOKEN definido (forte)
out="$(run "export OMNI_AGENT_TOKEN='$STRONG'")"; check "a) só OMNI_AGENT_TOKEN" pass "$out" $?
# (b) só OMNI_PIPELINE_AGENT_TOKEN definido (forte)
out="$(run "export OMNI_PIPELINE_AGENT_TOKEN='$STRONG'")"; check "b) só OMNI_PIPELINE_AGENT_TOKEN" pass "$out" $?
# (c) ambas iguais (fortes)
out="$(run "export OMNI_AGENT_TOKEN='$STRONG'; export OMNI_PIPELINE_AGENT_TOKEN='$STRONG'")"; check "c) ambas iguais" pass "$out" $?
# (d) ambas diferentes → falha
out="$(run "export OMNI_AGENT_TOKEN='$STRONG'; export OMNI_PIPELINE_AGENT_TOKEN='$STRONG2'")"; check "d) ambas diferentes" fail "$out" $?
# (e) variável explícita fraca → falha
out="$(run "export OMNI_AGENT_TOKEN='$WEAK'")"; check "e) explícita fraca" fail "$out" $?
# (f) nenhuma definida → reutiliza/gera o arquivo local (token não-vazio, iguais)
out="$(run ":")"; check "f) nenhuma definida (arquivo)" pass "$out" $?

# (g) o token nunca é exibido (nem em sucesso nem em falha)
g_leak=0
run "export OMNI_AGENT_TOKEN='$STRONG'" >/dev/null 2>&1
grep -q "$STRONG" /tmp/agttok_out /tmp/agttok_err 2>/dev/null && g_leak=1
run "export OMNI_AGENT_TOKEN='$STRONG'; export OMNI_PIPELINE_AGENT_TOKEN='$STRONG2'" >/dev/null 2>&1
grep -q "$STRONG" /tmp/agttok_err 2>/dev/null && g_leak=1
grep -q "$STRONG2" /tmp/agttok_err 2>/dev/null && g_leak=1
if [ "$g_leak" -eq 0 ]; then echo "ok   — g) token nunca exibido (stdout/stderr)"; pass=$((pass+1));
else echo "FAIL — g) token vazou em stdout/stderr"; fail=$((fail+1)); fi

rm -f /tmp/agttok_out /tmp/agttok_err 2>/dev/null || true
echo "-----"
echo "agent_token: ${pass} ok, ${fail} fail"
[ "$fail" -eq 0 ]
