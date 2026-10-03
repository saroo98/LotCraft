# LotCraft 1.2.4 Build and Installation

## End-user installation

The release contains one self-contained Windows x64 installer:

```text
LotCraft-1.2.4-Setup.exe
```

1. Download the installer from the latest GitHub Release.
2. Double-click it.
3. Approve the detected MetaTrader 5 terminal data directory.
4. Refresh **Navigator → Expert Advisors** in MT5.
5. Attach **LotCraft** to a chart and enable **Allow DLL imports**.

The installer writes only these files:

```text
<terminal data directory>\MQL5\Experts\LotCraft\
  LotCraft.ex5
  LotCraft-Updater.exe
  LotCraft-Uninstall.exe
  LotCraft-install.json
```

The embedded EX5 and the installed copy are SHA-256 verified before the installation is accepted.

## Uninstall

Run:

```text
<terminal data directory>\MQL5\Experts\LotCraft\LotCraft-Uninstall.exe
```

The uninstaller validates the installation manifest and hashes before removal. It removes only the four LotCraft-owned files and preserves unrelated files.

## Build requirements

- Windows x64
- MetaTrader 5 and MetaEditor
- Go 1.23 or newer
- Python 3.11 or newer
- PowerShell 5.1 or newer
- An Ed25519 release-signing key stored outside the repository

The private signing key is required only for signed release creation, not for the offline tests. The full tests additionally use pytest, Git Bash and a C++17 g++ compiler. Native function tests explicitly skip when g++ is unavailable; a green run with those skips is not equivalent coverage.

The default private-key location is:

```text
%LOCALAPPDATA%\LotCraft\Signing\update-ed25519.key
```

The matching public key is tracked in `installer\update-public-key.txt` and embedded in the updater. The private key must remain restricted to the current Windows user and must never be committed or uploaded.

## Test

From the repository root:

```powershell
py -3.11 -m pytest -q
```

PE tests build a synthetic installer from current source in a temporary directory. They do not use an ignored prebuilt release or a real signing key. Go tests create disposable terminal-like directories and synthetic keys where required. Do not point test fixtures at a real terminal.

## Compile and build the installer

```powershell
.\scripts\build_release.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5\MetaEditor64.exe"
```

The release script:

1. Compiles `MQL5\Experts\LotCraft\LotCraft.mq5`.
2. Requires MetaEditor to report zero errors and zero warnings.
3. Temporarily copies the compiled EX5 into the Go installer package.
4. Builds a deterministic Windows GUI installer with the EX5 embedded.
5. Restores the exact prebuild embedded payload source bytes.
6. Stamps and verifies Windows version metadata.
7. Embeds the pinned Ed25519 public key in the installer/updater.
8. Stages the installer and EX5 under `release\LotCraft-1.2.4`.
9. Signs the exact final installer metadata as `LotCraft-update.json` and `LotCraft-update.sig`.
10. Verifies the signature and installer descriptor.
11. Writes release verification evidence. Public output must contain artifact roles, names and hashes, not absolute workspace or terminal paths.

Generated binaries and logs are excluded from Git. Inspect every asset before publication: ignore rules do not sanitize release uploads. With explicit owner approval, the v1.2.0 verification report was separately replaced with an artifact-name-only copy on 2026-09-30. Its installer, checksum, signed metadata and signature are unchanged. The [1.2.1 release report](RELEASE_1.2.1.md) records the comparison; cached historical copies are outside this repair.

## Compile, install and verify a local terminal

Use the real MT5 terminal data directory, not its `MQL5` subfolder. The installer requires at least one normal terminal-data marker: `config`, `bases`, `history`, `logs`, or `origin.txt`. An empty `MQL5` directory alone is not sufficient:

```powershell
.\scripts\build_release.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5\MetaEditor64.exe" `
  -Install `
  -TerminalDataDir "$env:APPDATA\MetaQuotes\Terminal\<terminal-id>"
```

This local verification confirms that:

- compilation completed with zero errors and warnings;
- the canonical and staged EX5 files are byte-identical;
- the installer completed successfully;
- the installed EX5 is byte-identical to the canonical build.
- the installed updater and manifest use the four-file updater-aware schema.

## Update-release contract

Every stable GitHub release must publish:

```text
LotCraft-<version>-Setup.exe
LotCraft-update.json
LotCraft-update.sig
```

The signed JSON records the schema, product, stable semantic version, tag, installer filename, byte size, and SHA-256. The detached signature covers the exact JSON bytes. Drafts, prereleases, downgrades, bad signatures, unexpected hosts, unsafe or excessive redirects, hash or size mismatches, and oversized downloads are rejected. HTTPS redirects to allowed hosts are permitted within the configured hop limit.

## Controlled explicit-payload mode

The self-contained installer is the normal end-user path. For release engineering only, an explicit canonical payload can override the embedded payload:

```powershell
.\LotCraft-1.2.4-Setup.exe `
  -terminal-data-dir "C:\path\to\terminal\data" `
  -payload "C:\path\to\LotCraft.ex5" `
  -quiet
```

The explicit payload must be a regular, non-reparse file named exactly `LotCraft.ex5`.

Explicit-payload verification proves the supplied payload was installed, not that the executable embeds those same bytes. Verify an embedded installation in a disposable terminal-like directory when testing the self-contained package. Never use an arbitrary payload override for an end-user update.

## Audit build and rollback limits

An audit can copy sources into an ignored audit-owned build directory and invoke MetaEditor with hidden `/compile` and `/log` arguments. This produces compiler evidence without installing, signing, publishing or replacing the canonical release. The current audit uses this boundary.

Setup stages four owned files and uses per-file rename/rollback. This is not a crash-atomic four-file commit. Recovery errors must retain available backups and state that restoration is incomplete. Do not promise preservation after power loss or an unrecoverable filesystem failure.

Version 1.2.1 offers a detached launch ten seconds after initialization and then hourly while attached. The updater still applies its shared 24-hour network-attempt throttle, including failures. A due attempt can wait until the next hourly opportunity. Old 1.2.0 EAs need reattachment or restart for their next eligible launch; publication cannot change the already-loaded binary. A new version becomes active only after reattachment or a later terminal restart.

## Manual source compilation

Open `MQL5\Experts\LotCraft\LotCraft.mq5` in MetaEditor and compile it. The end-user installer intentionally contains only the compiled EA, not the source tree.
