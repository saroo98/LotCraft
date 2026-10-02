#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
TMP="$BUILD/.tmp"
RAW="$TMP/LotCraft-1.2.3-Setup.unstamped.exe"
FINAL="$BUILD/LotCraft-1.2.3-Setup.exe"
PAYLOAD="$ROOT/MQL5/Experts/LotCraft/LotCraft.ex5"
EMBEDDED="$ROOT/installer/cmd/setup/embedded_payload.txt"
KEY_FILE="$ROOT/installer/update-public-key.txt"

mkdir -p "$TMP"
if [[ ! -s "$PAYLOAD" ]]; then
  printf 'Missing compiled payload: %s\n' "$PAYLOAD" >&2
  exit 1
fi
if [[ ! -f "$KEY_FILE" ]]; then
  printf 'Missing pinned update public key.\n' >&2
  exit 1
fi
PUBLIC_KEY="$(tr -d '\r\n' < "$KEY_FILE")"
if [[ ! "$PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
  printf 'Invalid pinned Ed25519 update public key.\n' >&2
  exit 1
fi
EMBEDDED_BACKUP="$(mktemp "$TMP/embedded-payload.XXXXXX")"
cp "$EMBEDDED" "$EMBEDDED_BACKUP"
trap 'cp "$EMBEDDED_BACKUP" "$EMBEDDED"; rm -f -- "$EMBEDDED_BACKUP"' EXIT
cp "$PAYLOAD" "$EMBEDDED"
(
  cd "$ROOT/installer"
  GOOS=windows GOARCH=amd64 go build \
    -trimpath \
    -buildvcs=false \
    -ldflags="-s -w -H=windowsgui -buildid= -X lotcraft.local/installer/internal/update.TrustedPublicKeyBase64=$PUBLIC_KEY" \
    -o "$RAW" \
    ./cmd/setup
)
python3 "$ROOT/scripts/stamp_pe_version.py" "$RAW" "$FINAL"
python3 "$ROOT/scripts/stamp_pe_version.py" "$FINAL" "$FINAL" --verify-only
printf 'Built %s\n' "$FINAL"
sha256sum "$FINAL"
