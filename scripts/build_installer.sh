#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
TMP="$BUILD/.tmp"
RAW="$TMP/LotCraft-1.1.0-Setup.unstamped.exe"
FINAL="$BUILD/LotCraft-1.1.0-Setup.exe"
PAYLOAD="$ROOT/MQL5/Experts/LotCraft/LotCraft.ex5"
EMBEDDED="$ROOT/installer/cmd/setup/embedded_payload.txt"
PLACEHOLDER='Build placeholder. scripts/build_release.ps1 temporarily replaces this file with the compiled LotCraft.ex5 payload.'

mkdir -p "$TMP"
if [[ ! -s "$PAYLOAD" ]]; then
  printf 'Missing compiled payload: %s\n' "$PAYLOAD" >&2
  exit 1
fi
cp "$PAYLOAD" "$EMBEDDED"
trap 'printf "%s\n" "$PLACEHOLDER" > "$EMBEDDED"' EXIT
(
  cd "$ROOT/installer"
  GOOS=windows GOARCH=amd64 go build \
    -trimpath \
    -buildvcs=false \
    -ldflags='-s -w -H=windowsgui -buildid=' \
    -o "$RAW" \
    ./cmd/setup
)
python3 "$ROOT/scripts/stamp_pe_version.py" "$RAW" "$FINAL"
python3 "$ROOT/scripts/stamp_pe_version.py" "$FINAL" "$FINAL" --verify-only
printf 'Built %s\n' "$FINAL"
sha256sum "$FINAL"
