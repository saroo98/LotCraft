#!/usr/bin/env python3
"""Verify LotCraft release artifacts without manufacturing missing evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PRODUCT = "LotCraft"
VERSION = "1.0.0"
SUMMARY_RE = re.compile(r"(?i)(\d+)\s+errors?\s*,\s*(\d+)\s+warnings?")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_text_auto(path: Path) -> str:
    raw = path.read_bytes()
    encodings = []
    if raw.startswith(b"\xff\xfe") or b"\x00" in raw[:256]:
        encodings.extend(["utf-16", "utf-16-le"])
    encodings.extend(["utf-8-sig", "cp1252"])
    for encoding in encodings:
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            pass
    return raw.decode("utf-8", errors="replace")


def artifact_record(path: Path) -> dict[str, Any]:
    record: dict[str, Any] = {"path": str(path.resolve()), "exists": path.is_file()}
    if not record["exists"]:
        record.update({"size": None, "sha256": None})
        return record
    record["size"] = path.stat().st_size
    record["sha256"] = sha256_file(path)
    return record


def compile_record(path: Path) -> dict[str, Any]:
    record: dict[str, Any] = {"path": str(path.resolve()), "exists": path.is_file()}
    if not record["exists"]:
        record.update({"summary_found": False, "errors": None, "warnings": None, "passed": False})
        return record
    text = read_text_auto(path)
    matches = SUMMARY_RE.findall(text)
    if not matches:
        record.update({"summary_found": False, "errors": None, "warnings": None, "passed": False})
        return record
    errors, warnings = (int(value) for value in matches[-1])
    record.update({"summary_found": True, "errors": errors, "warnings": warnings, "passed": errors == 0 and warnings == 0})
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    root_default = Path(__file__).resolve().parents[1]
    parser.add_argument("--project-root", type=Path, default=root_default)
    parser.add_argument("--release-dir", type=Path)
    parser.add_argument("--compile-log", type=Path)
    parser.add_argument("--canonical-ex5", type=Path)
    parser.add_argument("--staged-ex5", type=Path)
    parser.add_argument("--installed-ex5", type=Path)
    parser.add_argument("--installer", type=Path)
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-sums", type=Path)
    parser.add_argument("--require-installed", action="store_true")
    args = parser.parse_args()

    project = args.project_root.resolve()
    release_dir = (args.release_dir or project / "release" / f"{PRODUCT}-{VERSION}").resolve()
    compile_log = (args.compile_log or project / "build" / "metaeditor" / f"{PRODUCT}-compile.log").resolve()
    canonical_ex5 = (args.canonical_ex5 or project / "MQL5" / "Experts" / PRODUCT / f"{PRODUCT}.ex5").resolve()
    staged_ex5 = (args.staged_ex5 or release_dir / f"{PRODUCT}.ex5").resolve()
    installer = (args.installer or release_dir / f"{PRODUCT}-{VERSION}-Setup.exe").resolve()
    installed_ex5 = args.installed_ex5.resolve() if args.installed_ex5 else None
    output_json = (args.output_json or release_dir / "RELEASE-VERIFICATION.json").resolve()
    output_sums = (args.output_sums or release_dir / "SHA256SUMS.txt").resolve()

    compile_info = compile_record(compile_log)
    canonical = artifact_record(canonical_ex5)
    staged = artifact_record(staged_ex5)
    setup = artifact_record(installer)
    installed = artifact_record(installed_ex5) if installed_ex5 else {
        "path": None,
        "exists": False,
        "size": None,
        "sha256": None,
        "not_requested": True,
    }

    canonical_nonempty = bool(canonical["exists"] and canonical["size"] and canonical["size"] > 0)
    staged_nonempty = bool(staged["exists"] and staged["size"] and staged["size"] > 0)
    setup_nonempty = bool(setup["exists"] and setup["size"] and setup["size"] > 0)
    canonical_staged_equal = bool(canonical_nonempty and staged_nonempty and canonical["sha256"] == staged["sha256"])
    installed_equal = bool(
        installed.get("exists")
        and installed.get("size")
        and installed["size"] > 0
        and canonical_nonempty
        and installed["sha256"] == canonical["sha256"]
    )

    stage_passed = bool(compile_info["passed"] and canonical_staged_equal and setup_nonempty)
    complete = bool(stage_passed and (installed_equal if args.require_installed else True))

    report = {
        "product": PRODUCT,
        "version": VERSION,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "compile": compile_info,
        "artifacts": {
            "canonical_ex5": canonical,
            "staged_installer_ex5": staged,
            "installed_ex5": installed,
            "installer": setup,
        },
        "comparisons": {
            "canonical_equals_staged": canonical_staged_equal,
            "canonical_equals_installed": installed_equal,
        },
        "requirements": {
            "installed_ex5_required": args.require_installed,
            "stage_passed": stage_passed,
            "complete": complete,
        },
    }

    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    sum_rows: list[tuple[str, str]] = []
    for label, record in [
        ("canonical-ex5", canonical),
        ("staged-installer-ex5", staged),
        ("installed-ex5", installed),
        ("installer", setup),
    ]:
        if record.get("sha256"):
            sum_rows.append((record["sha256"], f"{label}  {record['path']}"))
    output_sums.parent.mkdir(parents=True, exist_ok=True)
    output_sums.write_text("".join(f"{digest}  {label}\n" for digest, label in sum_rows), encoding="utf-8")

    print(json.dumps(report, indent=2))
    if not complete:
        print(
            "Release verification is incomplete. Missing or failed evidence is recorded in "
            f"{output_json}.",
            file=sys.stderr,
        )
        return 1
    print(f"Release verification passed: {output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
