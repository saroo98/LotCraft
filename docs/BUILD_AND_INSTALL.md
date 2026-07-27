# LotCraft 1.0.0 Build and Installation

## End-user installation

The release contains one self-contained Windows x64 installer:

```text
LotCraft-1.0.0-Setup.exe
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
  LotCraft-Uninstall.exe
  LotCraft-install.json
```

The embedded EX5 and the installed copy are SHA-256 verified before the installation is accepted.

## Uninstall

Run:

```text
<terminal data directory>\MQL5\Experts\LotCraft\LotCraft-Uninstall.exe
```

The uninstaller validates the installation manifest and hashes before removal. It removes only the three LotCraft-owned files and preserves unrelated files.

## Build requirements

- Windows x64
- MetaTrader 5 and MetaEditor
- Go 1.23 or newer
- Python 3.11 or newer
- PowerShell 5.1 or newer

## Test

From the repository root:

```powershell
py -3.11 -m pytest -q
```

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
5. Removes the temporary embedded payload source.
6. Stamps and verifies Windows version metadata.
7. Stages the installer and EX5 under `release\LotCraft-1.0.0`.
8. Writes a machine-local release verification report.

Generated binaries, logs, hashes and machine-specific verification evidence are excluded from Git.

## Compile, install and verify a local terminal

Use a real MT5 terminal data directory, meaning the directory that contains `MQL5`, `config`, `bases`, or another normal terminal marker:

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

## Controlled explicit-payload mode

The self-contained installer is the normal end-user path. For release engineering only, an explicit canonical payload can override the embedded payload:

```powershell
.\LotCraft-1.0.0-Setup.exe `
  -terminal-data-dir "C:\path\to\terminal\data" `
  -payload "C:\path\to\LotCraft.ex5" `
  -quiet
```

The explicit payload must be a regular, non-reparse file named exactly `LotCraft.ex5`.

## Manual source compilation

Open `MQL5\Experts\LotCraft\LotCraft.mq5` in MetaEditor and compile it. The end-user installer intentionally contains only the compiled EA, not the source tree.
