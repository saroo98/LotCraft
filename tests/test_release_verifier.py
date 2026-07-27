from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "verify_release.py"


def run_verifier(tmp_path: Path, compile_summary: str = "Result: 0 errors, 0 warnings", *, require_installed: bool = False, installed_matches: bool = True):
    compile_log = tmp_path / "compile.log"
    compile_log.write_text(compile_summary, encoding="utf-16")
    canonical = tmp_path / "canonical" / "LotCraft.ex5"
    staged = tmp_path / "release" / "LotCraft.ex5"
    installer = tmp_path / "release" / "LotCraft-1.0.0-Setup.exe"
    installed = tmp_path / "terminal" / "MQL5" / "Experts" / "LotCraft" / "LotCraft.ex5"
    for path in [canonical, staged, installer, installed]:
        path.parent.mkdir(parents=True, exist_ok=True)
    canonical.write_bytes(b"canonical-ex5")
    staged.write_bytes(b"canonical-ex5")
    installer.write_bytes(b"installer")
    installed.write_bytes(b"canonical-ex5" if installed_matches else b"different")

    args = [
        sys.executable,
        str(SCRIPT),
        "--project-root", str(tmp_path),
        "--release-dir", str(tmp_path / "release"),
        "--compile-log", str(compile_log),
        "--canonical-ex5", str(canonical),
        "--staged-ex5", str(staged),
        "--installer", str(installer),
    ]
    if require_installed:
        args += ["--installed-ex5", str(installed), "--require-installed"]
    result = subprocess.run(args, text=True, capture_output=True, check=False)
    report = json.loads((tmp_path / "release" / "RELEASE-VERIFICATION.json").read_text(encoding="utf-8"))
    return result, report


def test_release_verifier_accepts_clean_compile_and_equal_staged_binary(tmp_path: Path):
    result, report = run_verifier(tmp_path)
    assert result.returncode == 0
    assert report["compile"]["passed"] is True
    assert report["comparisons"]["canonical_equals_staged"] is True
    assert report["requirements"]["stage_passed"] is True


def test_release_verifier_requires_installed_hash_when_requested(tmp_path: Path):
    result, report = run_verifier(tmp_path, require_installed=True, installed_matches=False)
    assert result.returncode == 1
    assert report["comparisons"]["canonical_equals_installed"] is False
    assert report["requirements"]["complete"] is False


def test_release_verifier_rejects_compiler_warnings(tmp_path: Path):
    result, report = run_verifier(tmp_path, compile_summary="Result: 0 errors, 1 warnings")
    assert result.returncode == 1
    assert report["compile"]["warnings"] == 1
    assert report["compile"]["passed"] is False
