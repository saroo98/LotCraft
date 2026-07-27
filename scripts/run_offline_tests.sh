#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build

pytest -q --junitxml=build/pytest-results.xml
(
  cd installer
  go test ./...
  go test -race ./...
  go vet ./...
)
./scripts/build_installer.sh
python3 scripts/stamp_pe_version.py build/LotCraft-1.0.0-Setup.exe build/LotCraft-1.0.0-Setup.exe --verify-only
git diff --check
