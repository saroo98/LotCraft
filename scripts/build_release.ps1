[CmdletBinding()]
param(
    [string]$MetaEditorPath,
    [string]$TerminalDataDir,
    [switch]$Install,
    [switch]$AllowReparse,
    [string]$PythonCommand = "python",
    [string]$ReleaseDirectory,
    [string]$UpdateSigningKeyPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Product = "LotCraft"
$Version = "1.1.0"
$Source = Join-Path $ProjectRoot "MQL5\Experts\LotCraft\LotCraft.mq5"
$CanonicalEx5 = Join-Path $ProjectRoot "MQL5\Experts\LotCraft\LotCraft.ex5"
$BuildRoot = Join-Path $ProjectRoot "build"
$CompileRoot = Join-Path $BuildRoot "metaeditor"
$CompileLog = Join-Path $CompileRoot "LotCraft-compile.log"
$InstallerSource = Join-Path $BuildRoot "LotCraft-1.1.0-Setup.exe"
if ([string]::IsNullOrWhiteSpace($ReleaseDirectory)) {
    $ReleaseDirectory = Join-Path $ProjectRoot "release\LotCraft-1.1.0"
}
$ReleaseDirectory = [System.IO.Path]::GetFullPath($ReleaseDirectory)
$StagedEx5 = Join-Path $ReleaseDirectory "LotCraft.ex5"
$StagedInstaller = Join-Path $ReleaseDirectory "LotCraft-1.1.0-Setup.exe"
$UpdateManifest = Join-Path $ReleaseDirectory "LotCraft-update.json"
$UpdateSignature = Join-Path $ReleaseDirectory "LotCraft-update.sig"
$ReleaseChecksum = Join-Path $ReleaseDirectory "LotCraft-1.1.0-SHA256.txt"
$UpdatePublicKeyFile = Join-Path $ProjectRoot "installer\update-public-key.txt"
$EmbeddedEx5 = Join-Path $ProjectRoot "installer\cmd\setup\embedded_payload.txt"
$RawInstaller = Join-Path $BuildRoot ".tmp\LotCraft-1.1.0-Setup.unstamped.exe"
if ([string]::IsNullOrWhiteSpace($UpdateSigningKeyPath)) {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        throw "LOCALAPPDATA is unavailable. Supply -UpdateSigningKeyPath explicitly."
    }
    $UpdateSigningKeyPath = Join-Path $env:LOCALAPPDATA "LotCraft\Signing\update-ed25519.key"
}
$UpdateSigningKeyPath = [System.IO.Path]::GetFullPath($UpdateSigningKeyPath)

function Resolve-MetaEditorPath {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        $resolved = (Resolve-Path $Explicit -ErrorAction Stop).Path
        if (-not (Test-Path $resolved -PathType Leaf)) { throw "MetaEditor executable is not a file: $resolved" }
        return $resolved
    }

    foreach ($name in @("metaeditor64.exe", "metaeditor.exe")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $command) { return $command.Source }
    }

    $candidates = @(
        (Join-Path ${env:ProgramFiles} "MetaTrader 5\metaeditor64.exe"),
        (Join-Path ${env:ProgramFiles} "MetaTrader 5\metaeditor.exe")
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "MetaTrader 5\metaeditor.exe"
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate -PathType Leaf)) { return (Resolve-Path $candidate).Path }
    }
    throw "MetaEditor was not found. Supply -MetaEditorPath with the real metaeditor64.exe or metaeditor.exe path."
}

function Get-CompileSummary {
    param([string]$Path)
    if (-not (Test-Path $Path -PathType Leaf)) { throw "MetaEditor did not produce a compile log: $Path" }
    $text = [System.IO.File]::ReadAllText($Path)
    $matches = [regex]::Matches($text, "(?i)(\d+)\s+errors?\s*,\s*(\d+)\s+warnings?")
    if ($matches.Count -eq 0) { throw "No compiler error/warning summary was found in $Path" }
    $last = $matches[$matches.Count - 1]
    return [pscustomobject]@{
        Errors = [int]$last.Groups[1].Value
        Warnings = [int]$last.Groups[2].Value
    }
}

$MetaEditor = Resolve-MetaEditorPath $MetaEditorPath
if (-not (Test-Path $UpdatePublicKeyFile -PathType Leaf)) {
    throw "The pinned update public key is missing: $UpdatePublicKeyFile"
}
if (-not (Test-Path $UpdateSigningKeyPath -PathType Leaf)) {
    throw "The private update signing key is missing: $UpdateSigningKeyPath"
}
$UpdatePublicKey = ([System.IO.File]::ReadAllText($UpdatePublicKeyFile)).Trim()
if ($UpdatePublicKey -notmatch '^[A-Za-z0-9+/]{43}=$') {
    throw "The pinned update public key is not a valid base64 Ed25519 public key."
}
New-Item -ItemType Directory -Path $CompileRoot -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDirectory -Force | Out-Null
Remove-Item $CompileLog -Force -ErrorAction SilentlyContinue
Remove-Item $CanonicalEx5 -Force -ErrorAction SilentlyContinue

$compileArgs = @("/compile:`"$Source`"", "/log:`"$CompileLog`"")
$process = Start-Process -FilePath $MetaEditor -ArgumentList $compileArgs -Wait -PassThru
$summary = Get-CompileSummary $CompileLog
if ($summary.Errors -ne 0 -or $summary.Warnings -ne 0) {
    throw "MetaEditor compile failed acceptance: $($summary.Errors) errors, $($summary.Warnings) warnings. Log: $CompileLog"
}
if (-not (Test-Path $CanonicalEx5 -PathType Leaf) -or (Get-Item $CanonicalEx5).Length -le 0) {
    throw "MetaEditor reported a clean compile but no nonempty canonical EX5 exists at $CanonicalEx5"
}
New-Item -ItemType Directory -Path (Split-Path $RawInstaller) -Force | Out-Null
Copy-Item $CanonicalEx5 $EmbeddedEx5 -Force
try {
    Push-Location (Join-Path $ProjectRoot "installer")
    try {
        $GoLinkerFlags = "-s -w -H=windowsgui -buildid= -X lotcraft.local/installer/internal/update.TrustedPublicKeyBase64=$UpdatePublicKey"
        & go build -trimpath -buildvcs=false "-ldflags=$GoLinkerFlags" -o $RawInstaller .\cmd\setup
        if ($LASTEXITCODE -ne 0) { throw "Go installer build failed with exit code $LASTEXITCODE" }
    }
    finally { Pop-Location }
    & $PythonCommand (Join-Path $ProjectRoot "scripts\stamp_pe_version.py") $RawInstaller $InstallerSource
    if ($LASTEXITCODE -ne 0) { throw "Installer version stamping failed with exit code $LASTEXITCODE" }
    & $PythonCommand (Join-Path $ProjectRoot "scripts\stamp_pe_version.py") $InstallerSource $InstallerSource --verify-only
    if ($LASTEXITCODE -ne 0) { throw "Installer metadata verification failed with exit code $LASTEXITCODE" }
}
finally {
    [System.IO.File]::WriteAllText(
        $EmbeddedEx5,
        "Build placeholder. scripts/build_release.ps1 temporarily replaces this file with the compiled LotCraft.ex5 payload.`n",
        (New-Object System.Text.UTF8Encoding($false))
    )
}

Copy-Item $CanonicalEx5 $StagedEx5 -Force
Copy-Item $InstallerSource $StagedInstaller -Force

Push-Location (Join-Path $ProjectRoot "installer")
try {
    & go run .\cmd\releasesign sign `
        -private-key $UpdateSigningKeyPath `
        -installer $StagedInstaller `
        -version $Version `
        -tag "v$Version" `
        -manifest $UpdateManifest `
        -signature $UpdateSignature
    if ($LASTEXITCODE -ne 0) { throw "Release signing failed with exit code $LASTEXITCODE" }
    & go run .\cmd\releasesign verify `
        -public-key-file $UpdatePublicKeyFile `
        -manifest $UpdateManifest `
        -signature $UpdateSignature
    if ($LASTEXITCODE -ne 0) { throw "Release signature verification failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }

$InstallerDigest = (Get-FileHash $StagedInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $ReleaseChecksum,
    "$InstallerDigest  LotCraft-1.1.0-Setup.exe`n",
    (New-Object System.Text.UTF8Encoding($false))
)

$verifyArgs = @(
    (Join-Path $ProjectRoot "scripts\verify_release.py"),
    "--project-root", $ProjectRoot,
    "--release-dir", $ReleaseDirectory,
    "--compile-log", $CompileLog,
    "--canonical-ex5", $CanonicalEx5,
    "--staged-ex5", $StagedEx5,
    "--installer", $StagedInstaller,
    "--update-manifest", $UpdateManifest,
    "--update-signature", $UpdateSignature,
    "--update-public-key", $UpdatePublicKeyFile
)

if ($Install) {
    if ([string]::IsNullOrWhiteSpace($TerminalDataDir)) {
        throw "-TerminalDataDir is required with -Install. Use the real MT5 data directory containing MQL5."
    }
    $TerminalDataDir = (Resolve-Path $TerminalDataDir -ErrorAction Stop).Path
    $InstallLog = Join-Path $BuildRoot "LotCraft-1.1.0-install.log"
    # Start-Process joins ArgumentList entries into one command line and does
    # not preserve array element boundaries for values containing spaces.
    # Use quoted -name=value tokens so the Go flag parser receives each path
    # as one argument on both Windows PowerShell 5.1 and PowerShell 7.
    $installerArgs = @(
        "`"-terminal-data-dir=$TerminalDataDir`"",
        "`"-payload=$StagedEx5`"",
        "-quiet",
        "`"-log=$InstallLog`""
    )
    if ($AllowReparse) { $installerArgs += "-allow-reparse" }
    $installProcess = Start-Process -FilePath $StagedInstaller -ArgumentList $installerArgs -Wait -PassThru
    if ($installProcess.ExitCode -ne 0) {
        throw "Installer returned exit code $($installProcess.ExitCode). Log: $InstallLog"
    }
    $InstalledEx5 = Join-Path $TerminalDataDir "MQL5\Experts\LotCraft\LotCraft.ex5"
    $verifyArgs += @("--installed-ex5", $InstalledEx5, "--require-installed")
}

& $PythonCommand @verifyArgs
if ($LASTEXITCODE -ne 0) { throw "Release verification failed. See RELEASE-VERIFICATION.json in $ReleaseDirectory" }

Write-Host "Compile result: 0 errors, 0 warnings"
Write-Host "Canonical EX5: $CanonicalEx5"
Write-Host "Staged EX5: $StagedEx5"
Write-Host "Installer: $StagedInstaller"
Write-Host "Signed update manifest: $UpdateManifest"
Write-Host "Signed update signature: $UpdateSignature"
if ($Install) { Write-Host "Installed EX5: $InstalledEx5" }
Write-Host "Release verification: $(Join-Path $ReleaseDirectory 'RELEASE-VERIFICATION.json')"
