"""Build test artifacts from the current sources, never an ignored old release."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest


ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="session")
def synthetic_installer(tmp_path_factory) -> Path:
    workspace = tmp_path_factory.mktemp("installer-current-source")
    shutil.copytree(ROOT / "installer", workspace / "installer")
    scripts = workspace / "scripts"
    scripts.mkdir()
    for name in ("build_installer.sh", "stamp_pe_version.py"):
        shutil.copy2(ROOT / "scripts" / name, scripts / name)
    payload = workspace / "MQL5" / "Experts" / "LotCraft" / "LotCraft.ex5"
    payload.parent.mkdir(parents=True)
    payload.write_bytes(b"Synthetic non-trading test payload\n" * 64)

    # Git Bash can run the cross-build script on Windows without starting WSL.
    bash = shutil.which("bash")
    if os.name == "nt":
        git_bash = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Git" / "bin" / "bash.exe"
        if git_bash.is_file():
            bash = str(git_bash)
    if not bash or not shutil.which("go"):
        pytest.fail("Installer artifact tests require Go and Bash; no historical binary is accepted.")

    tool_bin = workspace / "test-tools"
    tool_bin.mkdir()
    python_launcher = tool_bin / "python3"
    python_path = Path(sys.executable).as_posix().replace("'", "'\\''")
    python_launcher.write_text(f"#!/usr/bin/env bash\nexec '{python_path}' \"$@\"\n", encoding="utf-8")
    python_launcher.chmod(0o700)
    env = os.environ.copy()
    env["PATH"] = str(tool_bin) + os.pathsep + env["PATH"]
    options = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
    result = subprocess.run(
        [bash, str(scripts / "build_installer.sh")], cwd=workspace,
        env=env, capture_output=True, text=True, timeout=120, check=False, **options,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    output = workspace / "build" / "LotCraft-1.2.4-Setup.exe"
    assert output.is_file()
    return output
