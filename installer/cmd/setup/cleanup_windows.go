//go:build windows

package main

import (
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unicode/utf16"
	"unsafe"
)

// A system PowerShell process owns no LotCraft executable file. It can wait
// for a detached worker to exit, then delete that exact verified temporary
// file without requiring an administrator-only reboot deletion operation.
func scheduleDetachedExecutableCleanup(path string, parentPID int) error {
	resolved, directory, digest, err := validateDetachedCleanupTarget(path)
	if err != nil {
		return err
	}
	if parentPID <= 0 {
		return errors.New("cleanup parent process ID is invalid")
	}
	powershell, err := systemPowerShellPath()
	if err != nil {
		return err
	}
	local := os.Getenv("LOCALAPPDATA")
	if local == "" {
		return errors.New("LOCALAPPDATA is unavailable for cleanup diagnostics")
	}
	logDirectory := filepath.Join(local, "LotCraft", "Updater")
	script := fmt.Sprintf(`$ErrorActionPreference = 'Stop'
$target = %s
$directory = %s
$expectedHash = %s
$workerProcessId = %d
$logDirectory = %s
function Write-CleanupFailure {
    param([string]$reason)
    try {
        [IO.Directory]::CreateDirectory($logDirectory) | Out-Null
        $logPath = Join-Path $logDirectory 'cleanup.log'
        if ([IO.File]::Exists($logPath) -and (Get-Item -LiteralPath $logPath).Length -ge 1048576) {
            $previous = $logPath + '.1'
            if ([IO.File]::Exists($previous)) { Remove-Item -LiteralPath $previous -Force }
            Move-Item -LiteralPath $logPath -Destination $previous
        }
        if ($reason.Length -gt 1024) { $reason = $reason.Substring(0, 1024) }
        [IO.File]::AppendAllText($logPath, [DateTime]::UtcNow.ToString('o') + ' Temporary cleanup did not complete. Retained target: ' + $target + ' Reason: ' + $reason + [Environment]::NewLine)
    } catch {}
}
try {
    $parent = Get-Process -Id $workerProcessId -ErrorAction SilentlyContinue
    if ($null -ne $parent -and -not $parent.WaitForExit(60000)) { throw 'Cleanup parent did not exit.' }
    if (-not [IO.File]::Exists($target)) { exit 0 }
    $folder = Get-Item -LiteralPath $directory -Force
    $file = Get-Item -LiteralPath $target -Force
    if (($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or
        $file.DirectoryName -ine $directory) {
        throw 'Temporary cleanup path changed.'
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($target)
    try { $actualHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $hasher.Dispose() }
    if ($actualHash -ine $expectedHash) {
        throw 'Temporary cleanup identity changed.'
    }
    for ($attempt = 0; $attempt -lt 100; $attempt++) {
        try { Remove-Item -LiteralPath $target -Force; break }
        catch { if ($attempt -eq 99) { throw }; Start-Sleep -Milliseconds 50 }
    }
    # Never recurse. An unexpected extra file keeps the directory intact.
    if (@(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0) {
        Remove-Item -LiteralPath $directory -Force
    }
} catch { Write-CleanupFailure $_.Exception.Message; exit 1 }
`, powershellLiteral(resolved), powershellLiteral(directory), powershellLiteral(digest), parentPID, powershellLiteral(logDirectory))
	encoded := utf16.Encode([]rune(script))
	raw := make([]byte, len(encoded)*2)
	for index, value := range encoded {
		binary.LittleEndian.PutUint16(raw[index*2:], value)
	}
	command := exec.Command(powershell, "-NoLogo", "-NoProfile", "-NonInteractive", "-WindowStyle", "Hidden", "-EncodedCommand", base64.StdEncoding.EncodeToString(raw))
	command.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	if err := command.Start(); err != nil {
		return fmt.Errorf("start detached temporary cleanup: %w", err)
	}
	return command.Process.Release()
}

func validateDetachedCleanupTarget(path string) (string, string, string, error) {
	path, err := filepath.Abs(path)
	if err != nil {
		return "", "", "", err
	}
	path = filepath.Clean(path)
	directory := filepath.Dir(path)
	dirName := strings.ToLower(filepath.Base(directory))
	name := strings.ToLower(filepath.Base(path))
	updater := strings.HasPrefix(dirName, "lotcraft-updater-") && strings.HasPrefix(name, "lotcraft-updater-worker-")
	uninstallCleanup := strings.HasPrefix(dirName, "lotcraft-cleanup-") && strings.HasPrefix(name, "lotcraft-cleanup-")
	if (!updater && !uninstallCleanup) || filepath.Ext(name) != ".exe" {
		return "", "", "", errors.New("cleanup target is not a dedicated LotCraft temporary executable")
	}
	tempResolved, err := resolveExistingPath(os.TempDir())
	if err != nil {
		return "", "", "", err
	}
	parentResolved, err := resolveExistingPath(filepath.Dir(directory))
	if err != nil || !sameWindowsPath(tempResolved, parentResolved) {
		return "", "", "", errors.New("cleanup directory is not an immediate child of the verified temporary root")
	}
	attrs, err := getFileAttributes(directory)
	if err != nil || attrs&fileAttributeReparsePoint != 0 {
		return "", "", "", errors.New("cleanup directory is missing or is a reparse point")
	}
	if err := validateRegularNonReparseFile(path); err != nil {
		return "", "", "", fmt.Errorf("unsafe temporary cleanup file: %w", err)
	}
	digest, err := hashFile(path)
	if err != nil {
		return "", "", "", err
	}
	return path, directory, digest, nil
}

func powershellLiteral(value string) string {
	return "'" + strings.ReplaceAll(value, "'", "''") + "'"
}

func systemPowerShellPath() (string, error) {
	buffer := make([]uint16, 32768)
	length, _, callErr := kernel32.NewProc("GetSystemDirectoryW").Call(uintptr(unsafe.Pointer(&buffer[0])), uintptr(len(buffer)))
	if length == 0 || length >= uintptr(len(buffer)) {
		return "", windowsCallError("GetSystemDirectoryW", callErr)
	}
	path := filepath.Join(syscall.UTF16ToString(buffer[:length]), "WindowsPowerShell", "v1.0", "powershell.exe")
	if err := validateRegularNonReparseFile(path); err != nil {
		return "", fmt.Errorf("system PowerShell is unavailable: %w", err)
	}
	return path, nil
}
