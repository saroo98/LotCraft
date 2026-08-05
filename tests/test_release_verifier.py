from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "verify_release.py"


def run_verifier(
    tmp_path: Path,
    compile_summary: str = "Result: 0 errors, 0 warnings",
    *,
    require_installed: bool = False,
    installed_matches: bool = True,
    signed_update: bool = False,
    tamper_signature_input: bool = False,
):
    compile_log = tmp_path / "compile.log"
    compile_log.write_text(compile_summary, encoding="utf-16")
    canonical = tmp_path / "canonical" / "LotCraft.ex5"
    staged = tmp_path / "release" / "LotCraft.ex5"
    installer = tmp_path / "release" / "LotCraft-1.1.0-Setup.exe"
    installed = tmp_path / "terminal" / "MQL5" / "Experts" / "LotCraft" / "LotCraft.ex5"
    for path in [canonical, staged, installer, installed]:
        path.parent.mkdir(parents=True, exist_ok=True)
    canonical.write_bytes(b"canonical-ex5")
    staged.write_bytes(b"canonical-ex5")
    installer.write_bytes(b"installer")
    installed.write_bytes(b"canonical-ex5" if installed_matches else b"different")
    project_root = ROOT if signed_update else tmp_path

    args = [
        sys.executable,
        str(SCRIPT),
        "--project-root", str(project_root),
        "--release-dir", str(tmp_path / "release"),
        "--compile-log", str(compile_log),
        "--canonical-ex5", str(canonical),
        "--staged-ex5", str(staged),
        "--installer", str(installer),
    ]
    if signed_update:
        private_key = tmp_path / "signing" / "private.key"
        public_key = tmp_path / "signing" / "public.txt"
        manifest = tmp_path / "release" / "LotCraft-update.json"
        signature = tmp_path / "release" / "LotCraft-update.sig"
        subprocess.run(
            [
                "go", "run", "./cmd/releasesign", "generate",
                "-private-key", str(private_key),
                "-public-key", str(public_key),
            ],
            cwd=ROOT / "installer",
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(
            [
                "go", "run", "./cmd/releasesign", "sign",
                "-private-key", str(private_key),
                "-installer", str(installer),
                "-version", "1.1.0",
                "-tag", "v1.1.0",
                "-manifest", str(manifest),
                "-signature", str(signature),
            ],
            cwd=ROOT / "installer",
            check=True,
            capture_output=True,
            text=True,
        )
        if tamper_signature_input:
            manifest.write_bytes(manifest.read_bytes() + b" ")
        args += [
            "--update-manifest", str(manifest),
            "--update-signature", str(signature),
            "--update-public-key", str(public_key),
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


def test_release_verifier_accepts_matching_ed25519_metadata(tmp_path: Path):
    result, report = run_verifier(tmp_path, signed_update=True)
    assert result.returncode == 0
    assert report["artifacts"]["signed_update"]["signature_verified"] is True
    assert report["artifacts"]["signed_update"]["installer_descriptor_matches"] is True
    assert report["requirements"]["signed_update_passed"] is True


def test_release_verifier_rejects_tampered_signed_metadata(tmp_path: Path):
    result, report = run_verifier(tmp_path, signed_update=True, tamper_signature_input=True)
    assert result.returncode == 1
    assert report["artifacts"]["signed_update"]["signature_verified"] is False
    assert report["requirements"]["complete"] is False
