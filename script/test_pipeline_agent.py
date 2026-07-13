#!/usr/bin/env python3
"""Testes isolados do pipeline_agent (Onda 0 — endurecimento de segurança).

Somente biblioteca padrão (unittest). NÃO executa o pipeline real, NÃO acessa
Ollama, sync, banco ou dados pessoais: o subprocess é mockado e o servidor sobe
em 127.0.0.1:porta-efêmera dentro do próprio teste.

Executar:
    OMNI_AGENT_TOKEN=<forte> python script/test_pipeline_agent.py
(o próprio teste define um token forte de teste no ambiente antes de importar.)
"""
import importlib
import json
import os
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

STRONG_TOKEN = "t0ken-forte-de-teste-0123456789abcdef"  # >= 16 chars, só p/ teste


def _load_agent(env):
    """(Re)carrega o módulo do agente com um ambiente controlado."""
    for k in ("OMNI_AGENT_TOKEN", "OMNI_AGENT_HOST", "OMNI_AGENT_ALLOW_PUBLIC_BIND",
              "OMNI_AGENT_PORT", "OMNI_AGENT_MAX_BODY", "OMNI_PIPELINE_DIR"):
        os.environ.pop(k, None)
    os.environ.update(env)
    import pipeline_agent  # noqa: WPS433 (import local proposital p/ reload)
    return importlib.reload(pipeline_agent)


class StartupRulesTest(unittest.TestCase):
    """Regras de inicialização segura (sem subir servidor)."""

    def test_ausencia_de_token_impede_startup(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": ""})
        self.assertIsNotNone(agent.startup_error())
        self.assertIn("TOKEN", agent.startup_error())

    def test_token_fraco_impede_startup(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": "curto"})  # < 16
        self.assertIsNotNone(agent.startup_error())

    def test_token_forte_permite_startup_loopback(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": STRONG_TOKEN, "OMNI_AGENT_HOST": "127.0.0.1"})
        self.assertIsNone(agent.startup_error())

    def test_bind_publico_sem_optin_impede_startup(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": STRONG_TOKEN, "OMNI_AGENT_HOST": "0.0.0.0"})
        self.assertIsNotNone(agent.startup_error())
        self.assertIn("ALLOW_PUBLIC_BIND", agent.startup_error())

    def test_bind_publico_com_optin_permite_startup(self):
        # Configuração explícita usada pelo devstack (bind não-loopback + opt-in).
        agent = _load_agent({
            "OMNI_AGENT_TOKEN": STRONG_TOKEN,
            "OMNI_AGENT_HOST": "0.0.0.0",
            "OMNI_AGENT_ALLOW_PUBLIC_BIND": "1",
        })
        self.assertIsNone(agent.startup_error())

    def test_token_nunca_aparece_em_mensagem_de_erro(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": "curto"})
        self.assertNotIn("curto", agent.startup_error())


class FixedCommandTest(unittest.TestCase):
    """O comando é FIXO: nunca aceita comando/path/arg livre do cliente."""

    def test_build_cmd_e_fixo(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": STRONG_TOKEN, "OMNI_PIPELINE_DIR": "/tmp/x"})
        cmd = agent.build_cmd(False)
        self.assertEqual(cmd, [agent.PYTHON, str(agent.RUNNER)])
        cmd_skip = agent.build_cmd(True)
        self.assertEqual(cmd_skip, [agent.PYTHON, str(agent.RUNNER), "--skip-ingest"])

    def test_token_ok_tempo_constante(self):
        agent = _load_agent({"OMNI_AGENT_TOKEN": STRONG_TOKEN})
        self.assertTrue(agent.token_ok(STRONG_TOKEN))
        self.assertFalse(agent.token_ok("errado"))
        self.assertFalse(agent.token_ok(""))


class HttpServerTest(unittest.TestCase):
    """Sobe o servidor real em 127.0.0.1 e valida auth, corpo e /health."""

    @classmethod
    def setUpClass(cls):
        cls.agent = _load_agent({"OMNI_AGENT_TOKEN": STRONG_TOKEN,
                                 "OMNI_AGENT_HOST": "127.0.0.1",
                                 "OMNI_AGENT_MAX_BODY": "64"})
        # Mocka o pipeline: nunca executa subprocess real. Captura o skip_ingest.
        cls.calls = []

        def fake_run(skip_ingest):
            cls.calls.append(skip_ingest)
            return {"ok": True, "exit_code": 0, "timed_out": False, "summary": "exit=0"}

        cls.agent._run_pipeline = fake_run
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), cls.agent.Handler)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def _url(self, path):
        return f"http://127.0.0.1:{self.port}{path}"

    def _req(self, path, method="GET", token=None, body=None):
        data = body.encode() if body is not None else None
        req = urllib.request.Request(self._url(path), data=data, method=method)
        if token is not None:
            req.add_header("X-Agent-Token", token)
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status, json.loads(resp.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")

    def test_health_minimo_sem_dados_operacionais(self):
        status, body = self._req("/health")
        self.assertEqual(status, 200)
        self.assertEqual(set(body.keys()), {"ok", "runner_present"})
        # não vaza status/summary/paths/timestamps/erro
        for leak in ("last", "summary", "busy", "finished_at", "exit_code", "status"):
            self.assertNotIn(leak, body)

    def test_run_sem_token_retorna_401(self):
        status, body = self._req("/run", method="POST", body="{}")
        self.assertEqual(status, 401)

    def test_run_token_errado_retorna_401(self):
        status, _ = self._req("/run", method="POST", token="errado", body="{}")
        self.assertEqual(status, 401)

    def test_run_corpo_grande_retorna_413(self):
        big = json.dumps({"skip_ingest": True, "pad": "x" * 200})  # > MAX_BODY (64)
        status, _ = self._req("/run", method="POST", token=STRONG_TOKEN, body=big)
        self.assertEqual(status, 413)

    def test_run_autenticado_executa_comando_fixo(self):
        before = len(self.calls)
        status, body = self._req("/run", method="POST", token=STRONG_TOKEN,
                                 body=json.dumps({"skip_ingest": True}))
        self.assertEqual(status, 200)
        self.assertTrue(body["ok"])
        self.assertEqual(len(self.calls), before + 1)  # pipeline (mock) foi chamado 1x
        self.assertTrue(self.calls[-1])  # skip_ingest=True propagado (flag fixa)


if __name__ == "__main__":
    os.environ.setdefault("OMNI_AGENT_TOKEN", STRONG_TOKEN)
    unittest.main(verbosity=2)
