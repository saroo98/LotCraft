#!/usr/bin/env python3
"""Verify LotCraft release artifacts without manufacturing missing evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

PRODUCT = "LotCraft"
VERSION = "1.1.0"
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
    parser.add_argument("--update-manifest", type=Path)
    parser.add_argument("--update-signature", type=Path)
    parser.add_argument("--update-public-key", type=Path)
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
    update_manifest = args.update_manifest.resolve() if args.update_manifest else None
    update_signature = args.update_signature.resolve() if args.update_signature else None
    update_public_key = args.update_public_key.resolve() if args.update_public_key else None
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
    signed_update_requested = any((update_manifest, update_signature, update_public_key))
    signed_update = {
        "required": signed_update_requested,
        "manifest": artifact_record(update_manifest) if update_manifest else None,
        "signature": artifact_record(update_signature) if update_signature else None,
        "public_key": artifact_record(update_public_key) if update_public_key else None,
        "signature_verified": False,
        "installer_descriptor_matches": False,
        "error": None,
    }
    if signed_update_requested:
        if not all((update_manifest, update_signature, update_public_key)):
            signed_update["error"] = "All signed-update paths must be supplied together."
        elif not all(path.is_file() for path in (update_manifest, update_signature, update_public_key)):
            signed_update["error"] = "One or more signed-update artifacts are missing."
        else:
            verify = subprocess.run(
                [
                    "go", "run", "./cmd/releasesign", "verify",
                    "-public-key-file", str(update_public_key),
                    "-manifest", str(update_manifest),
                    "-signature", str(update_signature),
                ],
                cwd=project / "installer",
                text=True,
                capture_output=True,
                check=False,
            )
            signed_update["signature_verified"] = verify.returncode == 0
            if verify.returncode != 0:
                signed_update["error"] = (verify.stderr or verify.stdout).strip()
            try:
                metadata = json.loads(update_manifest.read_text(encoding="utf-8"))
                descriptor = metadata["installer"]
                signed_update["installer_descriptor_matches"] = bool(
                    metadata["schema_version"] == 1
                    and metadata["product"] == PRODUCT
                    and metadata["version"] == VERSION
                    and metadata["tag"] == f"v{VERSION}"
                    and descriptor["name"] == installer.name
                    and descriptor["size"] == setup["size"]
                    and descriptor["sha256"].lower() == setup["sha256"]
                )
            except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
                signed_update["error"] = f"Invalid signed update metadata: {exc}"

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

    signed_update_passed = bool(
        not signed_update_requested
        or (signed_update["signature_verified"] and signed_update["installer_descriptor_matches"])
    )
    stage_passed = bool(
        compile_info["passed"]
        and canonical_staged_equal
        and setup_nonempty
        and signed_update_passed
    )
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
            "signed_update": signed_update,
        },
        "comparisons": {
            "canonical_equals_staged": canonical_staged_equal,
            "canonical_equals_installed": installed_equal,
        },
        "requirements": {
            "installed_ex5_required": args.require_installed,
            "stage_passed": stage_passed,
            "signed_update_passed": signed_update_passed,
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
