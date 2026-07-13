#!/usr/bin/env python3
"""
PB-016a — Agente de pipeline do Omni (roda no HOST, onde estão as conversas).

Por que existe
--------------
O pipeline de coleta é Python Windows-nativo: lê %APPDATA%\\Code, ~/.codex e
~/.claude do perfil do usuário e EXIGE a variável APPDATA. O Omni (Rails) roda
em container Linux e não enxerga esses caminhos. Em vez de montar o perfil
inteiro no container (frágil e proibido pela PB-016a), o Omni dispara ESTE
agente via HTTP local; o agente executa o pipeline no ambiente nativo e devolve
só exit code + um resumo seguro. O Omni então importa /normalized.

F7.7 — o pipeline agora é NATIVO do Omni (app/pipeline/run_collect.py); NÃO depende
mais do RepoB em runtime. RepoB permanece apenas como referência read-only.

Segurança (Onda 0 — endurecimento)
-----------------------------------
- **Token forte obrigatório** (X-Agent-Token): sem `OMNI_AGENT_TOKEN` com pelo
  menos MIN_TOKEN_LEN caracteres, o agente **recusa iniciar**. Não há default
  utilizável. Comparação em tempo constante (hmac.compare_digest).
- **Bind loopback por padrão** (127.0.0.1). Bind não-loopback (ex.: 0.0.0.0 para
  o container alcançar) **exige opt-in explícito** `OMNI_AGENT_ALLOW_PUBLIC_BIND=1`;
  sem ele, o agente **recusa iniciar**.
- **Limite de corpo HTTP** (MAX_BODY): requests maiores recebem 413.
- **/health mínimo e sem segredos**: só `{"ok": true, "runner_present": bool}` —
  não expõe status de execução, resumo, paths, timestamps ou erro interno.
- comando FIXO: [python, run_collect.py [--skip-ingest]] — nunca recebe comando,
  path ou argumento livre do cliente;
- uma execução por vez (lock); /run é síncrono e devolve o resultado;
- timeout fixo configurável: mata o processo ao estourar;
- nunca loga token nem conteúdo de conversa/segredos; resumo só com as últimas
  linhas, com paths absolutos redigidos.

Autossuficiente: só biblioteca padrão (http.server, subprocess, json, hmac).

Uso
---
    OMNI_AGENT_TOKEN=<token-forte> python script/pipeline_agent.py
Variáveis de ambiente:
    OMNI_AGENT_TOKEN               (OBRIGATÓRIA) token forte compartilhado
    OMNI_AGENT_HOST               bind (default 127.0.0.1)
    OMNI_AGENT_ALLOW_PUBLIC_BIND  "1" p/ permitir bind não-loopback (opt-in)
    OMNI_AGENT_PORT               porta (default 8765)
    OMNI_AGENT_MAX_BODY           limite do corpo em bytes (default 1024)
    OMNI_PIPELINE_DIR             diretório do pipeline NATIVO
    OMNI_PIPELINE_PYTHON          executável python do pipeline
    OMNI_PIPELINE_TIMEOUT         timeout em segundos (default 1800)
"""
from __future__ import annotations

import hmac
import json
import os
import re
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

# --- Configuração (lida do ambiente; sem defaults inseguros) -----------------
MIN_TOKEN_LEN = 16
LOOPBACK_HOSTS = frozenset({"127.0.0.1", "::1", "localhost"})

HOST = os.environ.get("OMNI_AGENT_HOST", "127.0.0.1")
PORT = int(os.environ.get("OMNI_AGENT_PORT", "8765"))
TOKEN = os.environ.get("OMNI_AGENT_TOKEN", "")
ALLOW_PUBLIC_BIND = os.environ.get("OMNI_AGENT_ALLOW_PUBLIC_BIND", "").lower() in ("1", "true", "yes")
MAX_BODY = int(os.environ.get("OMNI_AGENT_MAX_BODY", "1024"))
PIPELINE_DIR = Path(os.environ.get("OMNI_PIPELINE_DIR", r"c:\Sandbox\_omni\app\pipeline"))
TIMEOUT = int(os.environ.get("OMNI_PIPELINE_TIMEOUT", "1800"))


# Executável Python do pipeline: usa o .venv se existir, senão "python".
def _resolve_python() -> str:
    explicit = os.environ.get("OMNI_PIPELINE_PYTHON")
    if explicit:
        return explicit
    venv = PIPELINE_DIR.parent / ".venv" / "Scripts" / "python.exe"
    return str(venv) if venv.exists() else "python"


PYTHON = _resolve_python()
# F7.7 — entrypoint NATIVO do Omni (coleta + normalização, sem report).
RUNNER = PIPELINE_DIR / "run_collect.py"

_lock = threading.Lock()
_last = {"status": "idle", "exit_code": None, "summary": None, "finished_at": None}

_ABS_PATH = re.compile(r"[A-Za-z]:\\[^\s]*|/[^\s]*/")


def is_loopback(host: str) -> bool:
    return host in LOOPBACK_HOSTS


def startup_error() -> str | None:
    """Regras de inicialização segura. Retorna a mensagem de erro ou None se OK.

    Não inclui o token na mensagem (nunca vazar segredo em log/erro).
    """
    if len(TOKEN) < MIN_TOKEN_LEN:
        return (f"OMNI_AGENT_TOKEN ausente ou fraco: defina um token forte "
                f"(>= {MIN_TOKEN_LEN} caracteres). Abortando.")
    if not is_loopback(HOST) and not ALLOW_PUBLIC_BIND:
        return (f"bind não-loopback ({HOST}) exige OMNI_AGENT_ALLOW_PUBLIC_BIND=1 "
                f"(opt-in explícito). Abortando.")
    return None


def token_ok(provided: str) -> bool:
    """Comparação em tempo constante do token do request."""
    return hmac.compare_digest(provided or "", TOKEN)


def build_cmd(skip_ingest: bool) -> list[str]:
    """Comando FIXO: nunca recebe comando/path/arg livre do cliente.

    `skip_ingest` só decide a presença de uma flag fixa do próprio runner.
    """
    cmd = [PYTHON, str(RUNNER)]
    if skip_ingest:
        cmd.append("--skip-ingest")
    return cmd


def _safe(text: str) -> str:
    return _ABS_PATH.sub("…", (text or "")).strip()


def _summarize(out: str, err: str, code) -> str:
    tail = (err or out or "").splitlines()[-8:]
    msg = f"exit={code}"
    if tail:
        msg += " · " + _safe(" ".join(tail))
    return msg[:500]


def _run_pipeline(skip_ingest: bool) -> dict:
    """Executa o pipeline com COMANDO FIXO. Sem input do cliente além do flag fixo."""
    if not RUNNER.exists():
        return {"ok": False, "exit_code": None, "timed_out": False,
                "summary": "Ambiente do pipeline inválido: run_collect.py ausente."}

    cmd = build_cmd(skip_ingest)

    try:
        proc = subprocess.run(
            cmd, cwd=str(PIPELINE_DIR), capture_output=True, text=True, timeout=TIMEOUT
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "exit_code": None, "timed_out": True,
                "summary": f"Pipeline excedeu o tempo limite ({TIMEOUT}s)."}
    except FileNotFoundError:
        return {"ok": False, "exit_code": None, "timed_out": False,
                "summary": "Ambiente do pipeline inválido: executável Python não encontrado."}

    code = proc.returncode
    return {"ok": code == 0, "exit_code": code, "timed_out": False,
            "summary": _summarize(proc.stdout, proc.stderr, code)}


class Handler(BaseHTTPRequestHandler):
    def _send(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authed(self) -> bool:
        return token_ok(self.headers.get("X-Agent-Token", ""))

    def log_message(self, *args):  # silencia o log default (não vaza paths/token)
        pass

    def do_GET(self):
        if self.path == "/health":
            # /health NÃO exige token e é MÍNIMO: só liveness + presença do runner.
            # Nunca expõe status/summary/paths/timestamps/erro (dados operacionais).
            self._send(200, {"ok": True, "runner_present": RUNNER.exists()})
            return
        if not self._authed():
            self._send(401, {"ok": False, "error": "unauthorized"})
            return
        if self.path == "/status":
            self._send(200, {"ok": True, "busy": _lock.locked(), "last": _last})
            return
        self._send(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if not self._authed():
            self._send(401, {"ok": False, "error": "unauthorized"})
            return
        if self.path != "/run":
            self._send(404, {"ok": False, "error": "not found"})
            return

        # Limite de corpo: rejeita Content-Length inválido/ausente-grande ou > MAX_BODY.
        try:
            length = int(self.headers.get("Content-Length", "0") or "0")
        except ValueError:
            self._send(400, {"ok": False, "error": "bad content-length"})
            return
        if length < 0 or length > MAX_BODY:
            self._send(413, {"ok": False, "error": "payload too large"})
            return

        # corpo opcional: { "skip_ingest": bool } — único parâmetro aceito (flag fixo).
        raw = self.rfile.read(length) if length else b"{}"
        try:
            params = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            params = {}
        skip_ingest = bool(params.get("skip_ingest", False)) if isinstance(params, dict) else False

        if not _lock.acquire(blocking=False):
            self._send(409, {"ok": False, "error": "already running"})
            return
        try:
            _last["status"] = "running"
            result = _run_pipeline(skip_ingest)
            _last.update(status="done", exit_code=result["exit_code"],
                         summary=result["summary"], finished_at=time.strftime("%Y-%m-%dT%H:%M:%S"))
            self._send(200, result)
        finally:
            _lock.release()


def main():
    err = startup_error()
    if err:
        print(f"[agent] ERRO: {err}", file=sys.stderr)
        sys.exit(1)
    if not RUNNER.exists():
        print(f"[agent] AVISO: run_collect.py não encontrado em {RUNNER}", file=sys.stderr)
    bind_note = "loopback" if is_loopback(HOST) else "público (opt-in)"
    print(f"[agent] Omni pipeline-agent escutando em {HOST}:{PORT} ({bind_note}; python={PYTHON})")
    print(f"[agent] pipeline_dir={PIPELINE_DIR} timeout={TIMEOUT}s max_body={MAX_BODY}B")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
