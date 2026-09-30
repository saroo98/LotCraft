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
# Pytest builds and inspects a disposable installer from the current Go source
# with a synthetic payload. Offline tests do not need a compiled or signed EA.
git diff --check
