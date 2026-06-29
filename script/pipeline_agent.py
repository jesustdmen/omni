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

Segurança
---------
- escuta em 127.0.0.1 (e, opcionalmente, no IP que o container alcança) e EXIGE
  um token compartilhado em todo request (header X-Agent-Token);
- comando FIXO: [python, run_collect.py [args fixos]] — nunca recebe comando,
  path ou argumento do cliente;
- uma execução por vez (lock); /run é síncrono e devolve o resultado;
- timeout fixo configurável: mata o processo ao estourar;
- nunca loga conteúdo de conversa/segredos; resumo só com as últimas linhas,
  com paths absolutos redigidos.

Autossuficiente: só biblioteca padrão (http.server, subprocess, json).

Uso
---
    python script/pipeline_agent.py
Variáveis de ambiente (todas opcionais; defaults para a máquina de dev):
    OMNI_AGENT_HOST     bind (default 0.0.0.0 — para o container alcançar)
    OMNI_AGENT_PORT     porta (default 8765)
    OMNI_AGENT_TOKEN    token compartilhado (default "omni-dev-agent")
    OMNI_PIPELINE_DIR   diretório do pipeline NATIVO (default c:\\Sandbox\\_omni\\app\\pipeline)
    OMNI_PIPELINE_PYTHON executável python do pipeline (default: .venv ou "python")
    OMNI_PIPELINE_TIMEOUT timeout em segundos (default 1800)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = os.environ.get("OMNI_AGENT_HOST", "0.0.0.0")
PORT = int(os.environ.get("OMNI_AGENT_PORT", "8765"))
TOKEN = os.environ.get("OMNI_AGENT_TOKEN", "omni-dev-agent")
PIPELINE_DIR = Path(os.environ.get("OMNI_PIPELINE_DIR", r"c:\Sandbox\_omni\app\pipeline"))
TIMEOUT = int(os.environ.get("OMNI_PIPELINE_TIMEOUT", "1800"))

# Executável Python do pipeline: usa o .venv do RepoB se existir, senão "python".
def _resolve_python() -> str:
    explicit = os.environ.get("OMNI_PIPELINE_PYTHON")
    if explicit:
        return explicit
    venv = PIPELINE_DIR.parent / ".venv" / "Scripts" / "python.exe"
    return str(venv) if venv.exists() else "python"

PYTHON = _resolve_python()
# F7.7 — entrypoint NATIVO do Omni (coleta + normalização, sem report). Antes apontava
# para o run_pipeline.py do RepoB; agora o pipeline é interno (app/pipeline).
RUNNER = PIPELINE_DIR / "run_collect.py"

_lock = threading.Lock()
_last = {"status": "idle", "exit_code": None, "summary": None, "finished_at": None}

_ABS_PATH = re.compile(r"[A-Za-z]:\\[^\s]*|/[^\s]*/")


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

    cmd = [PYTHON, str(RUNNER)]
    if skip_ingest:
        cmd.append("--skip-ingest")  # flag fixo do próprio runner (não é input livre)

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
        return self.headers.get("X-Agent-Token", "") == TOKEN

    def log_message(self, *args):  # silencia o log default (não vaza paths)
        pass

    def do_GET(self):
        if self.path == "/health":
            # health não exige token (só confirma que o agente está vivo + ambiente ok)
            self._send(200, {"ok": True, "runner_present": RUNNER.exists(),
                             "busy": _lock.locked(), "last": _last})
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

        # corpo opcional: { "skip_ingest": bool } — único parâmetro aceito (flag fixo).
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b"{}"
        try:
            params = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            params = {}
        skip_ingest = bool(params.get("skip_ingest", False))

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
    if not RUNNER.exists():
        print(f"[agent] AVISO: run_collect.py não encontrado em {RUNNER}", file=sys.stderr)
    print(f"[agent] Omni pipeline-agent escutando em {HOST}:{PORT} (python={PYTHON})")
    print(f"[agent] pipeline_dir={PIPELINE_DIR} timeout={TIMEOUT}s")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
