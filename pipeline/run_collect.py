"""
run_collect.py — Entrypoint NATIVO do Omni: coleta (ingest) + normalização.

F7.7 — internaliza o pipeline produtivo (antes em _origem/_repob), SEM alterar o
comportamento dos estágios. Roda apenas ingest -> normalize e **NÃO** roda report/
viewer: o contrato consumido pelo Omni é `summaries.jsonl` + `sessions.jsonl` +
`shards/{messages,summaries}/*` (ver docs/F7_CONTRACT_DECISIONS.md). `session_titles.json`
e `tags.json` são artefatos do viewer (fora desta frente).

O código dos estágios é cópia verbatim do pipeline legado; só o ENTRYPOINT é novo
(omite o report). Os paths de saída são relativos a este diretório (PIPELINE_ROOT),
portanto a saída fica em `app/pipeline/output/` (gitignored), sem depender do RepoB.

Uso (no host, a partir da raiz do app):
    python pipeline/run_collect.py                                  # coleta + normalização
    python pipeline/run_collect.py --skip-ingest                    # só normalização (snapshot mais recente)
    python pipeline/run_collect.py --skip-ingest --snapshot-dir DIR # normaliza um snapshot específico
"""

from __future__ import annotations

import argparse
import importlib.util
import sys
from pathlib import Path

# Raiz do app — necessária para os imports `pipeline.lib.*` dos estágios copiados.
_ROOT = Path(__file__).resolve().parent.parent
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

_PIPELINE_ROOT = Path(__file__).resolve().parent


def _import_stage(name: str, path: Path):
    """Importa um módulo de estágio por caminho absoluto (pastas começam com dígito)."""
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)        # type: ignore[arg-type]
    spec.loader.exec_module(mod)                       # type: ignore[union-attr]
    return mod


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Omni — coleta + normalização (sem report). Pipeline nativo (F7.7)."
    )
    parser.add_argument(
        "--skip-ingest",
        action="store_true",
        help="Pula o ingest e usa o snapshot mais recente (ou --snapshot-dir).",
    )
    parser.add_argument(
        "--snapshot-dir",
        type=Path,
        default=None,
        help="Snapshot específico para o normalize (padrão: mais recente em output/raw/).",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    snapshot_dir: Path | None = args.snapshot_dir

    # Bloco 1 — Ingestão (coleta do AppData/.codex/.claude; exige APPDATA — host Windows).
    if not args.skip_ingest:
        ingest_mod = _import_stage("ingest", _PIPELINE_ROOT / "01_ingest" / "ingest.py")
        snapshot_dir = ingest_mod.run_ingest(snapshot_dir=snapshot_dir)

    # Bloco 2 — Normalização (escreve o contrato produtivo em output/normalized/).
    norm_mod = _import_stage("normalize", _PIPELINE_ROOT / "02_normalize" / "normalize.py")
    sessions_path, summaries_path = norm_mod.run_normalize(snapshot_dir=snapshot_dir)

    print("\nColeta + normalização concluídas (sem report).")
    print(f"  sessions.jsonl  -> {sessions_path}")
    print(f"  summaries.jsonl -> {summaries_path}")


if __name__ == "__main__":
    main()
